# Google Sheets local caching

Google Sheets previews are persisted on the device in the Hive box
`sheet_cache_v1`. Each cache record stores its source and organization IDs,
sheet URL and name, columns, rows, fetch time, row count, and schema version.

## Architecture

```text
Preview screen
    |
    v
CachedDataSourceRepository ---- cache hit ----> SheetCacheManager
    |                                              |
    | cache miss / Refresh                         v
    +----> GoogleSheetsLoader                HiveSheetCacheStorage
               |                                  |
               +---- fresh sheet data ------------+
```

## Lifecycle and user controls

1. The preview checks Hive before making a network request.
2. A cache miss fetches the public CSV export, saves the parsed rows, then
   displays them. A cache hit displays the saved rows without contacting
   Google Sheets.
3. **Refresh** explicitly fetches the latest sheet and replaces the cached
   value.
4. **Delete cache** removes the local copy. The next load fetches it again.
5. Use the source form to connect and save multiple sheets. Each saved source
   retains its optional custom label, original URL/ID, tab name, range, and
   header row. Tap a source card to display its cached rows; long-press or use
   its action menu to refresh or delete that individual source.
6. Cards include the saved row count and last fetched timestamp.
7. Entries older than seven days are labelled stale, but remain available
   offline until deleted.
8. Signing out clears local sheet caches to prevent data from surviving a
   user switch. `AppUser` does not currently contain organization membership,
   so sign-out clears all sheet-cache entries rather than guessing a tenant.

## Storage, size, and schema

Hive stores data in the platform-specific application support directory.
`SheetCacheManager` enforces a 50 MiB limit per organization by evicting the
oldest fetched cache entries first. The `version` field is reserved for
future schema migrations. Cache contents are device-local and are not
synchronized between devices.

At app startup, bootstrap runs `Hive.initFlutter()`, registers
`SheetCacheModelAdapter` (type ID `100`), then opens `sheet_cache_v1` before
the UI starts. `hive_flutter` uses IndexedDB for web builds and the platform
application-support storage on native builds. The cached-sources provider
reads persisted rows when the data-source screen opens; the newest saved sheet
is displayed automatically. Selecting another cached source displays it
without a network request.

## Cloud sync (Firestore)

Connected data sources also persist to Firestore so they survive sign-out and
are restored on the next login with the same account.

- **Document path:** `users/{uid}/dataSources/{sourceId}` where `sourceId` is
  the same deterministic `spreadsheetId|sheetName|range|headerRow` id used
  locally. Ownership is proven by the path variable and the document's own
  `uid` field (see `firestore.rules`).
- **Document contents:** the `SheetCacheModel` JSON plus `uid` and
  `updatedAt`. Rows are capped by `capRowsForRemote` to 500 rows and 400 KiB
  of JSON so a document stays well below the 1 MiB Firestore limit; `rowCount`
  keeps the full fetched count, so truncation is visible as
  `rows.length < rowCount`.
- **When data is written:** after **Connect**, after **Refresh**, and after
  the inline refresh in the cache actions. Deletion removes the remote
  document too. Writes are fire-and-forget (`DataSourceSyncService` logs and
  swallows failures so the local, offline-first experience never blocks).
- **When data is restored:** automatically once per `(uid, organization)` pair
  on login/app start (the app shell watches
  `dataSourceSyncBootstrapProvider`), and manually via the **Sync cloud**
  button in the cache actions.
- **Merge rule:** last-write-wins by `fetchedAt`. A local cache entry wins
  when it is at least as fresh; otherwise the remote copy is restored and
  re-stamped with the current effective organization so it appears in the
  active tenant immediately.
- **Guard rails:** guest mode and builds without Firebase configuration use
  `NoopDataSourceRemoteStorage` — cloud sync is a no-op there and behaviour is
  identical to the local-only past.

## Troubleshooting

- Check debug logs for Hive initialization or persistence errors if a cache
  cannot be read or saved.
- `Cache HIT for sourceId: ...` means the sheet was restored locally;
  `Cache MISS for sourceId: ...` means a network fetch is expected.
- On web, inspect browser developer tools under Application/Storage/IndexedDB
  for the `sheet_cache_v1` database. Browser privacy settings or clearing site
  data can remove IndexedDB contents.
- Refresh requires a publicly viewable spreadsheet and an active network
  connection.
- Use **Delete cache**, then load the same source to force a clean download.
