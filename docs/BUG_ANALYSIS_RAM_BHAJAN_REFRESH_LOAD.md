# Bug analysis — Ram Bhajans / Refresh / Fresh-open timeout

**Date:** 2026-11-08  
**Scope:** Local stack (`localhost:5173` + `music-api :5000`)  
**Mode:** Investigation only — **no code changes in this pass**

---

## What you reported

| # | Symptom |
|---|--------|
| A | Admin edit/delete OK |
| B | Ram Bhajans: group Festival ↔ Devotional mismatch; one Offline fallback; Home card opens with no tracks |
| C | Fresh open shows red `TimeoutException after 0:00:35` then app works; avoid double loaders |
| D | Admin Refresh shows Success but does not pull real new JioSaavn tracks |

---

## Executive verdict

These are **three separate bugs**, not one:

1. **Two catalogue rows both titled “Ram Bhajans”** — working Festival banner vs broken Devotional duplicate.
2. **Admin Refresh can return Success without calling Jio** (client short-circuit + Refresh-All stamp).
3. **35s red timeout** is the Flutter admin HTTP client timeout during a slow/cold first API path — not a permanent crash.

---

## Bug B — Ram Bhajans Festival vs Devotional / Offline fallback / no tracks

### Proof (local DB file)

From `music-api/data/catalog_sections.json`:

| key | display_group | Jio token | status | tracks | banner | artwork |
|-----|---------------|-----------|--------|--------|--------|---------|
| `ram_bhajans` | **Festival Specials** | `rvEs7,4L1W5LBU7Q54OWwg__` | ok | **33** | **yes** | real CDN |
| `ram_bhajans_2` | **Devotional & Bhakti** | `0NuTZoKJ0Ew_` | **unavailable** | **0** | no | null → placeholder |

Created today (~14:16–14:22 UTC). Create path auto-suffixes `_2` when the slug key already exists.

### Why Home looks “wrong”

```
Admin edits Festival row (ram_bhajans)
        │
        ▼
Home Festival hero can show the working banner
        │
Home "Devotional & Bhakti" row still shows ram_bhajans_2
        │  (same title, different key/source_id)
        ▼
Card: placeholder art, open → 0 tracks
Admin row for _2: LIVE + ERR Offline fallback + 0 tracks
```

- Home groups by `display_group` and hides banners from normal shelves → Devotional card = **`ram_bhajans_2`**.
- Dedupe is by `sourceType|sourceId`, **not** title → both rows survive.
- Bad Jio token → resolve returns empty → meta `last_error: "Offline fallback"` / `unavailable`.
- Open uses detail GET; if song cache empty, detail can return **[] without waiting on Jio** → “No tracks yet”.

### Not primarily a “group save failed” bug

`display_group` does save on PUT. The mismatch you see is mostly **editing one row while Home shows the other**, plus banner vs shelf split.

### Correct fix logic (when you approve coding)

1. **Data hygiene (immediate):** Delete or disable `ram_bhajans_2`, **or** replace its URL with the working Festival token. Do not leave enabled shelves with 0 tracks + unavailable.
2. **Create guard:** Block enable / warn hard when preview/resolve returns 0 live tracks; avoid silent `_2` duplicates of same title unless intentional.
3. **Admin UX:** Warn on duplicate `display_title` / same slug; show `key` clearly so Festival vs Devotional rows are not confused.
4. **Home open:** If `items` empty but `source_url` present → one forced resolve (with timeout) before `TrackListScreen`, or show “Unavailable” instead of “No tracks yet”.
5. **Optional Home filter:** Hide `provider_status` unavailable / 0-track non-artist cards.

---

## Bug D — Admin Refresh “Success” but Jio not updated (main product moto)

### Root cause A — Flutter short-circuit (current local code)

`lib/data/music_repository.dart` → `refreshCatalogSection`:

```dart
// Prefer cached detail first (fast). Fall back to hard refresh only if empty.
final cached = await getCatalogSectionDetail(key);
if (cached != null && cached.items.isNotEmpty) {
  return cached;  // NEVER calls POST /api/catalog/sections/<key>/refresh
}
```

Admin then shows Success with that track count.  
**So: if cache already has songs → Success with zero Jio re-fetch.** That is a fake refresh for the product goal (“pull latest from JioSaavn”).

This short-circuit was added during today’s “open empty playlist / speed” work. It helps **open**, but must **not** be used for the Admin Refresh button.

### Root cause B — Refresh All stamps success before Jio finishes

`server.py` → `POST /api/catalog/sections/refresh-all`:

1. Sets `last_refresh = now` on every section.
2. Returns `{ success: true, sections: ... }` immediately.
3. Real `get_section_items(..., force_refresh=True)` runs only in a **background thread**.

UI looks “refreshed just now” even while Jio work is still pending (or fails quietly).

### Root cause C — Per-row POST `/refresh` can still be empty

Server single refresh **does** call `force_refresh=True` → `resolve_catalog_items`.  
For a dead URL (`ram_bhajans_2`) that correctly returns 0 / unavailable — Success UI must not claim “updated tracks”.

### Correct real-time refresh design

```
Admin ⟳ Refresh (one section)
  MUST always → POST /api/catalog/sections/<key>/refresh
  MUST NOT short-circuit via GET detail cache
  Success only if provider_status == ok AND (item_count > 0 OR honest empty playlist)
  Persist: items cache disk + section meta (last_refresh, artwork, item_count)
  Then: invalidate Flutter catalog cache + Home silent refresh

Admin Refresh All
  Option 1: return 202 accepted + job id; poll until done
  Option 2: await N enabled shelves with concurrency; return real results
  Do NOT stamp last_refresh / Success before Jio completes
```

Home/user path can stay cache-first (instant paint + background heal).  
**Admin Refresh is an operator tool — it must mean “re-pull from Jio now”.**

---

## Bug C — Red `TimeoutException after 0:00:35` on fresh open

### Exact source of “35 seconds”

Flutter `CustomApiProvider` uses `.timeout(Duration(seconds: 35))` on admin create / update / delete / reorder / rename / toggle.  
Dart’s timeout string is exactly what your dialog/snackbar shows when `e.toString()` is used.

Warm-up / Home list uses ~10s and often swallows errors — so the **red 35s toast** is usually an **admin mutation** (or overlapping save) during a cold/slow API, not the splash itself.

### Why “then everything works”

Cold API: first heavy catalogue path may still wait on Supabase / locks / disk hydrate. Later requests hit RAM and are fast (~0.1s list after fix). User retries → success.

Recent API commits (last ~1–2 days) already moved upsert/reconcile off the hot path (`9fa6009`, `ca14307`, …) because of these 35s timeouts — residual cold-start edges remain.

### Double loader (what you noticed)

1. `SplashScreen` — logo ~2.5s (keep this).  
2. Home `FutureBuilder` with no data → **“Made for you / Loading your music…”** skeleton.

That is a **second** wait surface after splash. Not a second splash asset — but feels like double loading.

### Correct UX logic

1. Splash = only full-screen branded wait.  
2. Home: paint disk cache immediately; never replace the Future with a pending one that clears UI (already partly fixed for pull-refresh).  
3. Never toast raw `TimeoutException` — map to friendly “Server busy, retry” via existing error helpers.  
4. Warm-up failures: log only, no red banner.  
5. Do **not** add another logo loader on Home.

---

## Compare ~1 day ago vs current (relevant)

### music-api (recent intent)

| Commit | Intent | Side effect on these bugs |
|--------|--------|---------------------------|
| Delete/orphan / Supabase-first | Stop deleted shelves resurrecting | Good for delete; cold GET can still block once |
| Refresh stamp + source_url resolve | Admin “Just now” + better resolve | Refresh All stamps **before** Jio → fake Success |
| Async Supabase / no block on every list | Kill 35s save timeouts | Mutations faster; Refresh All still async-fake |
| Create `_2` key on collision | Allow re-add same slug | Created **`ram_bhajans_2`** dead duplicate |

### music-app (recent intent)

| Commit / local change | Intent | Side effect |
|-----------------------|--------|-------------|
| Cache-first Home | Instant reopen | Good |
| Empty shelf / confirm dialogs | Fix blank TRACK rows + admin UX | Good |
| **Local: detail GET + refresh short-circuit** | Fast open when cache filled | **Breaks Admin Refresh moto** if cache non-empty |

---

## Recommended build order (when you say “fix”)

1. **Data:** Remove/fix `ram_bhajans_2` (or fix URL) — unblocks Home Devotional card immediately.  
2. **Refresh truth:** Split APIs in the client — `getCatalogSectionDetail` for open/hydrate; Admin Refresh **always** POST force refresh; Refresh All must not lie.  
3. **First-open polish:** Friendly timeout copy; Home no second full “Loading your music…” if splash already ran / cache exists.  
4. **Only then** optional harden: block enable on empty resolve, duplicate-title warnings.

---

## How a correct real-time catalogue should behave

```
JioSaavn (source of truth for songs)
        │  only on: create preview, Admin Refresh, scheduled heal
        ▼
API items cache (RAM + catalog_items_cache.json)
        │
        ├─→ Admin list/detail (honest status + counts)
        └─→ Home list (cache-first, bg revalidate)
                 │
                 └─→ Supabase catalog_sections = membership/order/group truth
                     (not a substitute for song payloads)
```

- **Membership/group edits** → local + Supabase (already the direction).  
- **Song freshness** → only a real force resolve updates tracks.  
- **Success UI** → only after that resolve (or explicit “queued”).

---

## Out of scope this doc

- Fly trial 5-minute machine stop (infra).  
- Deploying these findings to Vercel/Fly (wait until you approve fixes).
