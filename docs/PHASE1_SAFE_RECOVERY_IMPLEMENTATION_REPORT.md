# Phase 1 Safe Recovery Implementation Report

**Date:** 2026-11-09  
**Scope:** Step 0 hosting proof · R1 · R2 · R8 · R7 security audit  
**Status:** Targeted code changes in **music-app only**. No migration, deploy, APK/AAB, reset, or Layer C work.

---

## Step 0 — Production hosting (read-only)

| Surface | Evidence | Host |
|---------|----------|------|
| `AppConfig.customApiUrl` default | `lib/core/config/app_config.dart` | **`https://music-api-tq5i.onrender.com`** |
| Vercel web build | `vercel_build.sh` `--dart-define=CUSTOM_API_URL=…onrender.com` | **Render** |
| Vercel share rewrites | `vercel.json` / `web/vercel.json` | **Render** |
| Bundled `assets/.env` | `CUSTOM_API_URL=https://music-api-tq5i.onrender.com` | **Render** (if asset loaded at runtime) |
| Fly app | `fly status -a kalpkrut-beats-api` → machine **started**, `/health` **200** | Alive but **not** AppConfig/Vercel default |
| Render health | `GET https://music-api-tq5i.onrender.com/health` → **200** (~3s) | Live |

**Conclusion for live clients**

- **Flutter Web (Vercel):** proven → **Render**.
- **Play Store APK:** source default + shipped `assets/.env` → **Render**, unless a past Play upload used a different `--dart-define` (not visible from this repo alone). No Play Console dart-define export was available; code path evidence points to Render.

**Hosting was not changed.**

---

## Changes implemented

### R1 — Honest Save verification
**Files:** `lib/data/music_repository.dart`

- Create/update call `_verifyCatalogSectionPersisted` by **stable id** (preferred) then key.
- Verification order: API lite list → detail GET → Supabase `catalog_sections` by id/key.
- On miss: **throws `ProviderException`** (Admin already shows “Save failed”).
- No longer soft-succeeds with `debugPrint` only.

### R2 — Disk bypass vs Jio re-resolve
**Files:** `lib/data/music_repository.dart`

- `getCatalogSections(forceRefresh: true)` → internal `bypassDiskCache` only; **never** sends API `refresh=1`.
- Admin Jio re-resolve remains `refreshCatalogSection` → `POST .../refresh` (unchanged contract).
- Docs on methods clarify Home vs Admin paths.
- URL parsing / resolve / playback **untouched**.

### R8 — Cache health / preserve tracks
**Files:**  
- `lib/core/catalog/catalog_cache_policy.dart` (new)  
- `lib/data/music_repository.dart`  
- `test/unit/catalog_cache_policy_test.dart` (new)

- Metadata-only catalogues are **not** healthy track caches.
- Disk write only when `catalogTrackCacheLooksHealthy`.
- `mergeCatalogSectionTracks` keeps prior live tracks when network returns empty/unavailable (unless `source_url` changed).

### R7 — Admin key (separate security patch)
**Files:**  
- `lib/domain/providers/custom_api_provider.dart`  
- `.env.example`

- Removed hardcoded `X-Admin-Key: …` from Flutter client.
- Headers now: `Authorization: Bearer <Supabase JWT>` (+ optional empty `ADMIN_API_KEY` dart-define for CI only).
- Server already accepts JWT admin / env `ADMIN_API_KEY` / localhost — existing signed-in admins keep working.
- `.env.example` no longer embeds a real-looking admin secret.

**Rotation:** The previously hardcoded client string was exposed in APK/Web builds and `.env.example`. **If the same value is still set as `ADMIN_API_KEY` on Render/Fly, it should be rotated on the server.** This report does **not** claim rotation was performed.

---

## Layer C frozen

- No edits to durable track tables, sync workers, or `supabase/migrations/20261109_catalog_durable_sync.sql`.
- No production migration run.

---

## Tests run

### Flutter
```text
flutter analyze lib/data/music_repository.dart
→ No issues found

flutter test test/unit/catalog_cache_policy_test.dart test/unit/catalog_section_test.dart
→ 00:00 +9: All tests passed!
```

### Python (music-api, no product code change; env Supabase cleared to avoid hung reconcile)
```text
python -m pytest test/unit/test_admin_catalog.py::TestCatalogUrlParsing -q
→ 6 passed

python -m pytest test/unit/test_phase_b_c_crud.py::…test_1… ::…test_2… -q
(with SUPABASE_URL/ANON/SERVICE cleared)
→ 2 passed
```

Full `test_phase_b_c_crud.py` against live Supabase env can hang on reconcile (pre-existing); offline env used for reliable local gate.

### Not run (per safety rules)
- Production deploy  
- APK / AAB  
- Manual Android notification/queue device suite (no release build)  
- Live Admin create against production catalogue  

---

## Remaining risks

1. Play APK older than current source might still embed the old hardcoded admin header until next store build (not built here).
2. If production `ADMIN_API_KEY` still equals the old public client string, rotate server-side.
3. Create with empty `id` in API response falls back to key-only verify (still better than title/URL).
4. Full phase B/C suite needs mocked Supabase or isolated test DB to avoid network hang.
5. Render cold starts remain an infra latency risk (unchanged).

---

## Confirmations

| Requirement | Status |
|-------------|--------|
| No git reset / force-push / discard of runtime JSON | Yes |
| No production migration | Yes |
| No production deployment | Yes |
| No APK/AAB | Yes |
| Layer C frozen | Yes |
| Flask API / hosting unchanged | Yes |
| Jio parse / playback code paths not rewritten | Yes |

**Stop here — wait for approval before further phases or commits/deploy.**
