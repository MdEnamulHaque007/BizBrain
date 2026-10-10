import 'package:bizbrain/core/update/update_check_logic.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final store = <String, String>{};
  var latest = 'sha-deadbeef';
  var fetchCalls = 0;
  late UpdateCheckLogic logic;

  setUp(() {
    store.clear();
    latest = 'sha-deadbeef';
    fetchCalls = 0;
    logic = UpdateCheckLogic(
      read: (key) async => store[key],
      write: (key, value) async {
        store[key] = value;
      },
      fetchLatest: () async {
        fetchCalls++;
        return latest;
      },
    );
  });

  test('first check with no stored version stores it and reports false',
      () async {
    final status = await logic.check();

    expect(status.updateAvailable, isFalse);
    expect(status.version, isNull);
    expect(store['bizbrain_loaded_version'], 'sha-deadbeef');
  });

  test('same stored and fetched version reports false', () async {
    store['bizbrain_loaded_version'] = 'sha-deadbeef';

    final status = await logic.check();

    expect(status.updateAvailable, isFalse);
  });

  test('a different fetched version reports true with the new version',
      () async {
    store['bizbrain_loaded_version'] = 'sha-old';
    latest = 'sha-new';

    final status = await logic.check();

    expect(status.updateAvailable, isTrue);
    expect(status.version, 'sha-new');
  });

  test('cooldown skips the check within 24 hours without fetching', () async {
    store['bizbrain_last_update_check'] =
        DateTime.now().millisecondsSinceEpoch.toString();

    final status = await logic.check();

    expect(status.updateAvailable, isFalse);
    expect(fetchCalls, 0);
  });

  test('after the cooldown the check fetches again', () async {
    store['bizbrain_last_update_check'] =
        (DateTime.now().millisecondsSinceEpoch - 25 * 60 * 60 * 1000)
            .toString();

    final status = await logic.check();

    expect(fetchCalls, 1);
    expect(status.updateAvailable, isFalse);
    expect(store['bizbrain_loaded_version'], 'sha-deadbeef');
  });

  test('initialize stores the version silently without a notification',
      () async {
    await logic.initialize();

    expect(store['bizbrain_loaded_version'], 'sha-deadbeef');
  });

  test('acknowledge records the new version and keeps the next check quiet',
      () async {
    store['bizbrain_loaded_version'] = 'sha-old';
    latest = 'sha-new';

    await logic.acknowledge('sha-new');

    expect(store['bizbrain_loaded_version'], 'sha-new');
    expect(store['bizbrain_last_update_check'], isNotNull);

    final status = await logic.check();
    expect(status.updateAvailable, isFalse);
  });
}