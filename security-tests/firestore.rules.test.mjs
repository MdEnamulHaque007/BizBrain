// Firestore tenant security tests (Micro Step 1.6.8).
//
// Runs against the local Firestore Emulator only - project `demo-bizbrain`
// (a demo-* project can never reach production).
//
// Requires:
//   1. Firestore Emulator running:  firebase emulators:start --only firestore --project demo-bizbrain
//   2. npm install --save-dev @firebase/rules-unit-testing firebase
//
// Run:  node security-tests/firestore.rules.test.mjs

import { readFileSync } from 'node:fs';
import {
  assertFails,
  assertSucceeds,
  initializeTestEnvironment,
} from '@firebase/rules-unit-testing';

const PROJECT_ID = 'demo-bizbrain';
const HOST = '127.0.0.1';
const PORT = 8080;

let failures = 0;

async function test(name, fn) {
  try {
    await fn();
    console.log(`ok   - ${name}`);
  } catch (error) {
    failures++;
    console.error(`FAIL - ${name}`);
    console.error(`       ${error && error.message ? error.message : error}`);
  }
}

const testEnv = await initializeTestEnvironment({
  projectId: PROJECT_ID,
  firestore: {
    rules: readFileSync(new URL('../firestore.rules', import.meta.url), 'utf8'),
    host: HOST,
    port: PORT,
  },
});

try {
  // Isolated local data: wipe the demo project, then seed through the
  // rules-disabled context (equivalent to a trusted backend write).
  await testEnv.clearFirestore();
  await testEnv.withSecurityRulesDisabled(async (context) => {
    const db = context.firestore();
    await db.doc('organizations/org1').set({
      name: 'Org One',
      ownerId: 'alice',
      memberIds: ['alice', 'bob'],
      status: 'active',
    });
    await db.doc('organizations/org2').set({
      name: 'Org Two',
      ownerId: 'carol',
      memberIds: ['carol'],
      status: 'active',
    });
    await db.doc('organizations/org-invited').set({
      name: 'Org Invited',
      ownerId: 'alice',
      memberIds: ['dave'],
      status: 'active',
    });
    await db.doc('organizations/org-suspended').set({
      name: 'Org Suspended',
      ownerId: 'alice',
      memberIds: ['erin'],
      status: 'active',
    });
    await db.doc('organizations/org1/members/alice').set({
      userId: 'alice',
      role: 'owner',
      status: 'active',
    });
    await db.doc('organizations/org1/members/bob').set({
      userId: 'bob',
      role: 'viewer',
      status: 'active',
    });
    await db.doc('organizations/org-invited/members/dave').set({
      userId: 'dave',
      role: 'member',
      status: 'invited',
    });
    await db.doc('organizations/org-suspended/members/erin').set({
      userId: 'erin',
      role: 'member',
      status: 'suspended',
    });
  });

  const unauth = testEnv.unauthenticatedContext().firestore();
  const alice = testEnv.authenticatedContext('alice').firestore();
  const bob = testEnv.authenticatedContext('bob').firestore();
  const dave = testEnv.authenticatedContext('dave').firestore();
  const erin = testEnv.authenticatedContext('erin').firestore();

  await test('1. unauthenticated user cannot read an organization', async () => {
    await assertFails(unauth.doc('organizations/org1').get());
  });

  await test('2. active member can read their active organization', async () => {
    const snapshot = await assertSucceeds(alice.doc('organizations/org1').get());
    if (!snapshot.exists) throw new Error('organization document missing');
    if (snapshot.data().status !== 'active') throw new Error('wrong status');
  });

  await test('3. active member cannot read another organization', async () => {
    await assertFails(alice.doc('organizations/org2').get());
  });

  await test('4. invited member cannot read organization data', async () => {
    await assertFails(dave.doc('organizations/org-invited').get());
    await assertFails(
      dave.doc('organizations/org-invited/members/dave').get(),
    );
  });

  await test('5. suspended member cannot read organization data', async () => {
    await assertFails(erin.doc('organizations/org-suspended').get());
    await assertFails(
      erin.doc('organizations/org-suspended/members/erin').get(),
    );
  });

  await test('6. active member can read their own membership document', async () => {
    const snapshot = await assertSucceeds(
      alice.doc('organizations/org1/members/alice').get(),
    );
    if (!snapshot.exists) throw new Error('membership document missing');
    if (snapshot.data().status !== 'active') throw new Error('wrong status');
  });

  await test('7. active member cannot read another user\'s membership document', async () => {
    await assertFails(alice.doc('organizations/org1/members/bob').get());
  });

  await test('8. all client writes are denied', async () => {
    await assertFails(
      alice.doc('organizations/org1').set({ name: 'hijacked' }),
    );
    await assertFails(
      alice.doc('organizations/org1/members/alice').set({
        role: 'owner',
        status: 'active',
      }),
    );
    await assertFails(alice.doc('organizations/org1').delete());
    await assertFails(alice.doc('factories/f1').set({ name: 'x' }));
  });

  await test('9. unmatched Firestore paths are denied', async () => {
    await assertFails(unauth.doc('factories/f1').get());
    await assertFails(unauth.doc('unknownCollection/doc').get());
    await assertFails(unauth.doc('organizations/org1/members/alice').get());
  });

  await test('10. direct organization list query is denied', async () => {
    await assertFails(
      alice
        .collection('organizations')
        .where('memberIds', 'array-contains', 'alice')
        .where('status', '==', 'active')
        .get(),
    );
    await assertFails(alice.collection('organizations').get());
  });

  // Regression for the suspended-member exposure fixed in 1.6.13: even with
  // a stale `memberIds` array that still contains erin, direct organization
  // listing is denied for everyone, so the organization document never
  // reaches a suspended user.
  await test('11. suspended user cannot list organizations despite stale memberIds', async () => {
    await assertFails(
      erin
        .collection('organizations')
        .where('memberIds', 'array-contains', 'erin')
        .where('status', '==', 'active')
        .get(),
    );
  });

  await test('12. active user lists only their own active membership records', async () => {
    const snapshot = await assertSucceeds(
      alice
        .collectionGroup('members')
        .where('userId', '==', 'alice')
        .where('status', '==', 'active')
        .get(),
    );
    const paths = snapshot.docs.map((d) => d.ref.path).sort();
    if (JSON.stringify(paths) !== JSON.stringify(['organizations/org1/members/alice'])) {
      throw new Error(`unexpected result: ${paths.join(', ')}`);
    }
  });

  await test('13. suspended and invited memberships are excluded', async () => {
    // Filtered queries return nothing (status field proven at query time).
    const erinFiltered = await assertSucceeds(
      erin
        .collectionGroup('members')
        .where('userId', '==', 'erin')
        .where('status', '==', 'active')
        .get(),
    );
    if (erinFiltered.docs.length !== 0) throw new Error('erin got results');
    const daveFiltered = await assertSucceeds(
      dave
        .collectionGroup('members')
        .where('userId', '==', 'dave')
        .where('status', '==', 'active')
        .get(),
    );
    if (daveFiltered.docs.length !== 0) throw new Error('dave got results');

    // Broader query without the status filter: the non-active document
    // fails the list rule, so the whole query is denied.
    await assertFails(
      erin.collectionGroup('members').where('userId', '==', 'erin').get(),
    );
    await assertFails(
      dave.collectionGroup('members').where('userId', '==', 'dave').get(),
    );
  });

  await test('14. cross-user and unauthenticated membership queries are denied', async () => {
    // bob cannot query alice's membership records.
    await assertFails(
      bob
        .collectionGroup('members')
        .where('userId', '==', 'alice')
        .where('status', '==', 'active')
        .get(),
    );
    // Unauthenticated callers cannot list memberships at all.
    await assertFails(
      unauth.collectionGroup('members').where('userId', '==', 'alice').get(),
    );
    // An unfiltered collection-group query mixes in other users' records
    // and must fail.
    await assertFails(alice.collectionGroup('members').get());
  });
} finally {
  await testEnv.cleanup();
}

console.log(
  failures === 0
    ? '\nAll security tests passed.'
    : `\n${failures} security test(s) failed.`,
);
process.exit(failures === 0 ? 0 : 1);
