# Phase 1 — Catalogue CRUD / Supabase / JioSaavn Forensic Audit

**Status:** READ-ONLY complete — **no product code changed in this phase**  
**Date:** 2026-11-09  
**Repos:** `kalpeshborse105/music-app` · `kalpeshborse105/music-api`  
**Deploy targets:** Play APK · Vercel · Fly `kalpkrut-beats-api` · Supabase

---

## 1. Checkpoints examined

| Repo | Checkpoint SHA | Date | Message |
|------|----------------|------|---------|
| music-app | `7ec534d69182afd6a502739835b238bc73855311` | 2026-11-05 | Enable Android desugaring for FCM… |
| music-api | `f3dac4f7960ec6d92fb41e30dfdcef9146f09ca4` | 2026-11-05 | FCM fix with minor admin bugs |

| Repo | Current HEAD | Date |
|------|--------------|------|
| music-app | `338166d` | 2026-11-08 |
| music-api | `ca14307` | 2026-11-08 |

**October 27 note:** No commits on calendar 2025-10-27. Closest “stable load” era in late October 2026 includes:

- app: `d70b22d` — *eliminate force refresh on initial fetch and restore instant catalog load*
- api: `1308f59` / `dfd69f6` — *non-blocking sections response* / *eliminate background thread starvation*

Those Oct commits are **performance** ancestors. The named **Nov 5** checkpoints are the correct CRUD comparison baselines (admin still local-first, no Supabase-as-truth triangle).

**Working tree:** music-app has **uncommitted** further edits (detail GET, refresh short-circuit, broader cache wipe). Audit of **shipped** behaviour uses HEAD; WT called out separately.

---

## 2. Last reliably working posture (not a blind rollback)

### music-api @ `f3dac4f` — more reliable for Admin CRUD latency/stability

- Serve: memory → local JSON; Supabase only cold-start or **bg ~600s**
- Save: write JSON + short authority + **always async upsert**
- **No** upsert-time prune
- **No** “drop all local-only on every pull”
- Create blocked once on Jio then 201 — fewer “saved then gone” races
- Resolve used stored type/id/slug (no identity rewrite fighting TRACK)

**Known weakness at checkpoint:** delete could resurrect (upsert without prune + bg merge kept orphans).

### music-app @ `7ec534d` — clearer mutation semantics in places

- `updateCatalogSection`: `String? language` — **omit preserves**
- `forceRefresh` passed `refresh: forceRefresh` to API
- Stricter cache “healthy” gate
- Hard verify-or-throw on save

**Known weakness at checkpoint:** bundled seed **persisted** to disk (`375916f`) → old APKs / new installs could show deleted shelves.

### Recommended “restore posture” for Phase 2 (cherry-pick, not hard reset)

**Keep from later commits:**

| Keep | Why |
|------|-----|
| `ca14307` non-blocking load | Avoids 35s Flutter timeouts |
| `9fa6009` async mutation sync | Admin save speed |
| Hard multi-id DELETE (`ea015a6` intent) | Real DB delete |
| Key-only dedupe (`2768b49`) | Stops `_2` create wipe |
| Non-mutating `source_url` resolve (`c894652`) | TRACK type safety |
| Seed demotion (`1b29522`) | New install integrity |
| TRACK shelf Home (`bd0f0a7`) | Intended product |

**Reverse / redesign:**

| Reverse | Why |
|---------|-----|
| `aa11e38` TTL=0 blocking reconcile | Introduced 35s stalls |
| `a8235ec` drop-all-local-only as request truth | Create verify races |
| Upsert prune + 1800s prune-skip pair | Orphan ↔ resurrect loop |
| Refresh-all stamp-before-Jio | Fake Success |
| App `language = 'all'` always (`a912dbb`) | Can wipe language on update |
| App always-merge on forceRefresh (`338166d`) | Stale tracks after edit |
| App `forceRefresh` never sends `refresh=1` | Soft “hard refresh” |
| WT refresh short-circuit via detail GET | Fake per-row Refresh |

---

## 3. Exact commits that introduced regressions

### music-api

| Rank | Regression | Introduced | Later band-aids |
|------|------------|------------|-----------------|
| 1 | Every load blocked on full Supabase reconcile → ~35s timeouts | **`aa11e38`** (2026-11-08) | `ca14307`, `9fa6009` |
| 2 | Supabase-as-truth drops in-flight creates (“Persistence verification failed”) | **`a8235ec`** | `7e6d975`, `d2eddfb` |
| 3 | Prune-after-upsert ↔ create prune race ↔ prune-skip under authority | prune: **`ea015a6`**; skip: **`340da5c`** | sync lock / prefer live mem |
| 4 | Create `_2` wiped by source_id dedupe | pre-`2768b49` | **`2768b49`** fixed |
| 5 | Refresh-all stamps “Just now” before Jio | **`ea015a6`** + **`2d9c100`** | none real |
| 6 | `source_url` resolve mutated shared section TRACK→URL type | **`2d9c100`** | `fd074fe`, **`c894652`** |
| 7 | PUT update resolve still **omits `source_url=`** | long-standing; still HEAD ~4199–4200 | create path passes it |

### music-app

| Rank | Regression | Introduced | Notes |
|------|------------|------------|-------|
| 1 | Seed painted + **written** to disk → delete ghosts on install | **`375916f`** | Mitigated **`1b29522`** |
| 2 | `updateCatalogSection` always sends `language: 'all'` | **`a912dbb`** | Checkpoint was omit-to-preserve |
| 3 | `_mergeCatalogNetworkMeta` re-attaches stale items | **`eaf205b`**; forceRefresh skip in `1b29522`; **re-enabled always-merge in `338166d`** | Stale songs after admin change |
| 4 | `forceRefresh` no longer sends API `refresh=1` | post-checkpoint soft-refresh work | Local disk bypass only |
| 5 | Soft persistence verify (lite + debugPrint miss) | `e0d630d` → `2ab4b43` → `338166d` | Success without DB proof |
| 6 | Optional fields cannot clear (omit ≠ null) | both eras | subtitle/artwork/campaign |
| 7 | WT: Admin Refresh short-circuits to detail cache | **uncommitted** | Fake Success if items cached |
| 8 | TRACK shelf needs `items.length > 1` | **`338166d`** | Empty metadata-only looks “missing” |

---

## 4. Confirmed root causes (map to user symptoms)

| User symptom | Root cause |
|--------------|------------|
| Create sometimes fails / “saved then gone” | `a8235ec` drop-local + prune race (`340da5c` era); verify races with force reconcile |
| Edit not reliable | language always `'all'`; omit cannot clear; PUT resolve without `source_url`; soft verify |
| Delete OK in Admin, Home still shows | DB orphan + prune-skip; Flutter seed/Supabase fallback; incomplete cache key wipe |
| Old APK vs new install different catalogue | Seed persist (`375916f`); Fly disk JSON vs Supabase; long client TTL |
| Some sections old tracks / some new | Items cache per-key; merge reattaches stale; refresh-all stamps without Jio |
| Jio wrong/incomplete | Resolve without full URL on PUT; dead duplicate URLs (`ram_bhajans_2`); mock filter |
| Save timeouts | `aa11e38` blocking reconcile; 45s upsert; Flutter 35s admin timeout |
| Admin refresh slow / fake | Stamp-before-Jio; WT detail short-circuit; soft forceRefresh |
| Supabase / API / Flutter disagree | Three stores + authority window + async upsert without confirmed read-back |
| Sections disappear then reappear | Prune ↔ local-only drop ↔ orphan resurface when authority expires |
| TRACK not rendering as shelf | Type mutation (fixed partially); Home requires hydrated `items.length > 1` |

---

## 5. Suspicious areas — audit answers

### 5.1 `MusicRepository.updateCatalogSection()` language

**HEAD:** `String language = 'all'` + unconditional `'language': language` in JSON.  
**Checkpoint `7ec534d`:** `String? language` + `if (language != null)`.

**Risk:** Any caller that omits language resets section to `all`. Admin UI often passes current language — masks the bug — but API contract is wrong.

### 5.2 Optional field clearing

Pattern unchanged: `if (subtitle != null)`, `if (customArtworkUrl != null)`.  
Empty string / “clear” in UI → omit → **server keeps old value**.  
No explicit `null` clear protocol. **Must add** Phase 2: omit = preserve, JSON `null` = clear.

### 5.3 JioSaavn URL resolution

- Create: passes `source_url=` into `resolve_catalog_items` (HEAD ~4014–4019, ~4137).
- Update when URL changes: resolve **without** `source_url=` (HEAD ~4199–4200) — **regression vs create**.
- Never invent trending fallback when URL fails — good (empty/unavailable).
- Duplicate creates get `_2` keys — can leave broken enabled shelves (Ram Bhajans case).

### 5.4 Supabase synchronization

```
save_catalog_sections → local JSON + RAM + authority extend
                      → bg sync_catalog_to_supabase (upsert)
                      → prune only if outside authority (340da5c)

load_catalog_sections → mem first (ca14307)
                      → bg reconcile ≥45s outside authority
                      → cold: Supabase first

reconcile (a8235ec) → remote keys only → drop local-only “ghosts”
```

**Competing truths:** local JSON + 1800s authority + prune-skip vs Supabase membership.  
**Delete:** must hard-delete remote **and** confirm; cannot rely on later prune.

### 5.5 False-positive save verification

Client: lite list + soft miss (`debugPrint`) after `338166d`.  
Server create/update often `sync_db=False` → 201/200 before Supabase upsert finishes.  
**Success ≠ DB row proven.** Phase 2 must confirm by stable ID read from Supabase (or sync_db=True for single-row upsert).

### 5.6 Cache

| Layer | Risk |
|-------|------|
| API RAM `_CATALOG_SECTIONS_MEM` | Multi-instance / restart drift |
| `catalog_sections.json` | Can override newer DB if treated as truth |
| `catalog_items_cache.json` | Stale songs; Refresh All stamps clock without Jio |
| Flutter `catalog_sections_v4:*` | Incomplete invalidate; merge reattaches items |
| Bundled seed | Demoted at HEAD; still last-resort offline |
| Trending disk cache | Separate; OK if not used as catalogue membership |

### 5.7 Concurrent operations

Create while refresh-all / prune / reconcile → documented races (`340da5c`, `7e6d975`).  
Need: mutation lock or single-writer queue; prune only on explicit reconcile; never prune during create window.

### 5.8 Track type preservation

Partially fixed (`fd074fe`, `c894652`). Still fragile if PUT resolve omits URL and `_apply_source_url_identity` runs on shared dicts. Home shelves need real `items[]`.

### 5.9 Platform consistency

- `AppConfig.customApiUrl` default = Fly at checkpoint **and** HEAD.
- Vercel share rewrites → Fly (`vercel.json`); older Render host was the share mismatch (`9c01c72` fixed).
- APK does **not** need reinstall if: Supabase is membership truth **and** client invalidates cache on open / after TTL — currently long TTL + merge can hide updates until force path.

---

## 6. Target architecture (Phase 2 design — not yet implemented)

Aligned with your brief:

1. **Supabase `catalog_sections`** = authoritative **metadata** (membership, order, group, language, URLs, types).
2. **Jio items cache** = separate, keyed by stable section key + `source_id` (+ URL hash).
3. Fly may keep short-lived RAM/disk cache; **must not** permanently override newer Supabase `updated_at`.
4. CRUD: confirm DB before Success; invalidate section caches; Home silent refresh.
5. Admin Refresh = always force Jio resolve; stamp `last_refresh` **after** success.
6. Home open = cache-first; **never** full Jio refresh-all on every open.
7. No service-role keys in Flutter/APK/Web.

---

## 7. Phase 2 implementation order (minimal)

1. **API DELETE:** require confirmed Supabase delete; no resurrect via reconcile orphans.  
2. **API UPDATE:** pass `source_url` to resolve; omit-vs-null field rules; single-row confirm.  
3. **API CREATE:** key-only dedupe (keep); confirm Supabase row by id before 201 if possible.  
4. **API refresh-all / refresh:** stamp after Jio; no fake Success.  
5. **API load:** keep `ca14307` local-first + bg reconcile; do not restore `aa11e38`.  
6. **App update language:** restore optional language.  
7. **App refresh:** Admin always POST force; detail GET only for Home open hydrate.  
8. **App cache:** invalidate all `catalog_sections_v4:*`; do not merge stale items after admin mutation / when `updated_at` newer.  
9. **Tests:** expand `test_admin_catalog.py` + Flutter unit tests for the 25 cases.  
10. **Validate:** analyze, tests, APK/AAB, Fly health — **no blind prod deploy**.

---

## 8. Phase 1 deliverable checklist

| Item | Status |
|------|--------|
| Git history both repos | Done |
| Checkpoint diffs Nov 5 → HEAD | Done |
| Oct late-2026 load ancestors noted | Done |
| Suspicious areas 1–8 answered | Done |
| Regression commit table | Done |
| Restore posture (cherry-keep vs reverse) | Done |
| Product code modified | **None** |

---

## 9. What Phase 1 explicitly did **not** do

- No rollback / hard reset of either repo  
- No Fly/Vercel/Play deploy  
- No production Supabase deletes  
- No APK/AAB build  
- No claim that “everything works”

---

## 10. Next step

**Phase 2** starts only after this audit is accepted: apply the minimal restore posture above with tests proving CREATE / READ / UPDATE / DELETE / REORDER against Supabase and visibility from a second client.
