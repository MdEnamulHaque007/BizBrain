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
5. Entries older than seven days are labelled stale, but remain available
   offline until deleted.
6. Signing out clears local sheet caches to prevent data from surviving a
   user switch. `AppUser` does not currently contain organization membership,
   so sign-out clears all sheet-cache entries rather than guessing a tenant.

## Storage, size, and schema

Hive stores data in the platform-specific application support directory.
`SheetCacheManager` enforces a 50 MiB limit per organization by evicting the
oldest fetched cache entries first. The `version` field is reserved for
future schema migrations. Cache contents are device-local and are not
synchronized between devices.

## Troubleshooting

- Check debug logs for Hive initialization or persistence errors if a cache
  cannot be read or saved.
- Refresh requires a publicly viewable spreadsheet and an active network
  connection.
- Use **Delete cache**, then load the same source to force a clean download.
