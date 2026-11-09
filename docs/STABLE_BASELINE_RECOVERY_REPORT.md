# Kalpkrut Beats — Stable Baseline Recovery Report

**Mode:** READ-ONLY (Phases 1–4). **No code edits. No commits. No deploys. No migrations. No APK/AAB.**  
**Date:** 2026-11-09  
**Priority:** Live-user stability first · Database sync second · New features later  

---

## 1. Exact baselines, parents, and latest

### music-app (`kalpeshborse105/music-app`)

| Role | SHA | Date (IST) | Subject |
|------|-----|------------|---------|
| **Parent of Nov baseline** | `eaf205b94e5cb6e1747437bb15eec0904ab038b4` | 2026-11-05 00:46 | fix all bugs admin side done |
| **Candidate Nov baseline** | `7ec534d69182afd6a502739835b238bc73855311` | 2026-11-05 00:55 | Enable Android desugaring for FCM… |
| **Latest (HEAD = origin/main)** | `9bf7ff56ba6c15d41726b7d2bdad33e3356454e3` | 2026-11-09 18:31 | Update player_screen.dart |

- Commits after baseline: **25**  
- App working tree: **clean**  
- Note: `7ec534d` itself only touched Android desugaring. Catalogue behaviour at that point comes from parent **`eaf205b`**.

### music-api (`kalpeshborse105/music-api`)

| Role | SHA | Date (IST) | Subject |
|------|-----|------------|---------|
| **True Nov 4 parent** | `5ba2b977aac0c9105d2494c7d28190d8bab3e210` | 2026-11-04 12:09 | fix minor bugs and refresh issue |
| **Candidate Nov baseline** | `f3dac4f7960ec6d92fb41e30dfdcef9146f09ca4` | 2026-11-05 00:46 | FCM fix with minor admin bugs |
| **Latest (HEAD = origin/main)** | `9cd85421d6ebbe824e091ed3f8615a28d8af0696` | 2026-11-09 17:18 | security(catalog): remove hardcoded service-role… + durable sync migration |

- Commits after baseline: **18**  
- API working tree: **dirty only** `data/catalog_sections.json` + `data/catalog_items_cache.json` (runtime cache — **do not discard**; not logic)  

### Baseline verification (do not assume Nov 4/5 is perfect)

| Checkpoint | Strengths for live users | Known weaknesses |
|------------|--------------------------|------------------|
| App `eaf205b` / `7ec534d` | Admin CRUD felt stable; `forceRefresh` could send `refresh=1`; harder save verify | Seed painted+persisted → delete ghosts; merge reattached stale items |
| API `5ba2b97` (Nov 4) | Simpler sync; fewer prune/reconcile races | Weak delete durability (orphans could return) |
| API `f3dac4f` | Authority window; unique positions; admin auth parity; fly.toml always-on | Still upsert-without-prune; no full `source_url` resolve yet |

**Verdict:** Best **surgical restore posture** is **not** `git reset` to Nov 4. Prefer **cherry KEEP** from later commits + **RESTORE** a short regression list. Parent `5ba2b97` alone would reintroduce delete orphans.

---

## 2. File-by-file comparison (high-signal)

### music-app — catalogue / playback / config changed after `7ec534d`

| File | Nature of change | Class hint |
|------|------------------|------------|
| `lib/data/music_repository.dart` | Cache-first, soft verify, merge rules, detail hydrate, omit-vs-null (late) | KEEP most · RESTORE soft-verify / soft-forceRefresh |
| `lib/domain/providers/custom_api_provider.dart` | Timeouts, lite list, detail GET, hardcoded admin key | KEEP API surface · RESTORE secret-in-client |
| `lib/domain/models/catalog_section.dart` | `displayMode`, junk filter, itemCount honesty | KEEP |
| `lib/ui/screens/admin_screen.dart` | Confirm dialogs, refresh UX, reorder | KEEP |
| `lib/ui/screens/home_screen.dart` | TRACK shelves, cache-first, hydrate | KEEP |
| `lib/core/cache/cache_store.dart` | `keys` for prefix wipe | KEEP |
| `lib/core/config/app_config.dart` | Default API Fly → Render | SEPARATE (hosting) |
| `vercel_build.sh` / share rewrites | Fly excursion then back to Render | SEPARATE |
| `lib/domain/playback/*` | `_activeTrack`, queue ID match, stream fallback | KEEP |
| `lib/ui/screens/player_screen.dart` | UI polish (`9bf7ff5`) | SEPARATE / KEEP UI |
| `android/` after baseline | **No catalogue/playback native changes** | — |
| `supabase/migrations/20261109_catalog_durable_sync.sql` | Durable sync schema | SEPARATE (not run) |
| `docs/PHASE1_*` / phase tests | Audit artefacts | SEPARATE |

### music-api — catalogue / sync / resolve after `f3dac4f`

| Area | Baseline | Latest | Class hint |
|------|----------|--------|------------|
| `parse_catalog_url` | Stable | **Unchanged** | KEEP |
| Stream / play / jiosaavn stream | Stable | **Unchanged** | KEEP |
| `resolve_catalog_items` + `source_url` | id/slug only | Full URL + TRACK preserve | KEEP |
| `save_catalog_sections` / authority | 600s, async upsert, no prune | 1800s, sync_db flag, gated prune | KEEP gated design |
| `load_catalog_sections` | local-first | local-first again after `ca14307` (was blocking in `aa11e38`) | KEEP non-blocking |
| DELETE | local + soft remote | remote-first + confirm intent | KEEP |
| refresh-all | absent / early stamp | job/status + workers | KEEP API · SEPARATE workers |
| Durable tracks/jobs + SQL migration | absent | present in `9cd8542` | SEPARATE |
| Hardcoded service-role | removed then **reintroduced** `ad653d5` then removed `9cd8542` | KEEP `9cd8542` security |
| `fly.toml` | always-on / rolling | unchanged after baseline | KEEP ops |

---

## 3. Classification

### A. KEEP — proven safe / required for live users

**JioSaavn / resolve (do not roll back)**  
- Unchanged `parse_catalog_url`  
- Full `source_url` resolve (`2d9c100`)  
- Non-mutating resolve copy + TRACK/`display_mode` preserve (`fd074fe`, `c894652`)  
- new-releases identity + junk track filter (`35cc3c2` / app `d5ee23a`)  
- Stream/play handlers unchanged  

**Admin CRUD durability (keep intent)**  
- Hard remote DELETE first (`ea015a6` → refined `9b5356a`)  
- Key-only dedupe (`2768b49`) — stops `_2` create wipe  
- Authority window + prune **skipped during admin lease** (`340da5c`)  
- Create upsert-first / async fill (`9fa6009`, later honesty commits)  
- Non-blocking catalogue load (`ca14307`) — undoes `aa11e38`  
- App: omit-vs-null clears + honest admin refresh (`2d2a4bf`)  
- App: seed demotion, no persist as live catalogue (`1b29522`)  
- App: TRACK song shelves (`bd0f0a7`)  
- App: Home cache-first + trending cache (`f979a80`) — for UX speed  
- App: playback `_activeTrack` / next-track / duration / stream fallback (`a042258`, `f98ae09`)  
- Security: no hardcoded service-role (`9cd8542`)  

### B. RESTORE — regressions vs verified working behaviour

| ID | Regression | Old (baseline-era) | Current | Reproducible failure | Minimal fix (proposal only) |
|----|------------|--------------------|---------|----------------------|-----------------------------|
| R1 | Soft save verification | Hard refresh + throw on miss | Lite list + `debugPrint` keep-on-miss (`e0d630d`→`338166d`) | Admin Save Success while section missing on second client | Restore hard fail **or** confirm by stable ID in Supabase before Success |
| R2 | Soft `forceRefresh` | Could send API `refresh=1` | Disk bypass only; `refresh: false` (`f979a80`) | Home/Admin “refresh” does not re-pull Jio tracks | Split: `bypassDisk` vs `reResolveJio=true` (admin-only) |
| R3 | Blocking reconcile (already mostly undone) | Local-first | Was `aa11e38` TTL=0 every load | 35s Flutter timeouts | **Never reintroduce**; keep `ca14307` |
| R4 | Ungated prune / create race (mitigated) | No prune | Early `ea015a6` pruned N+1 | 201 then “Persistence verification failed” | Keep `340da5c` gate; never ungated prune on save |
| R5 | Hardcoded service-role oscillation | Env-only | `ad653d5` reintroduced secret | Security / wrong project access risk | Keep `9cd8542`; forbid re-hardcoding |
| R6 | Hosting skew (Fly ↔ Render) | Fly default mid-range | HEAD default **Render** (`6d36eb3`) | APK/Web hit different cold hosts; confusion | SEPARATE decision: pick **one** live API host and pin AppConfig + Vercel + Play define |
| R7 | Client hardcoded `X-Admin-Key` | Not in APK the same way | Still in `custom_api_provider.dart` | Secret in Play APK | Move off client or rotate; SEPARATE security PR |
| R8 | Thin-cache health gate | Stricter filled ratio | `filled≥1 \|\| length≥5` | Metadata-only catalogues cached as healthy | Tighten health before disk write |
| R9 | Supabase fallback resurrection | Seed was worse | API fail → Supabase select can show deleted rows | Delete in Admin; Home still shows | On force path skip; membership reads prefer API after confirmed delete |

**Already fixed in HEAD (do not “restore” by reverting the fix):**  
language always `'all'` (`a912dbb` → fixed `2d2a4bf`); Admin refresh detail short-circuit (fixed `2d2a4bf`); TRACK RAM mutation (fixed `c894652`).

### C. SEPARATE — isolate from JioSaavn / Admin hot path

| Item | Why separate |
|------|----------------|
| `supabase/migrations/20261109_catalog_durable_sync.sql` | New tables/jobs; **do not run on production** in this recovery |
| Phase D/G sync workers / job leases (`9b3cda3`) | CPU saturation risk; not required for Jio preview/save/play |
| Full-table upsert on reorder vs single-row on create | Normalize later; don’t block stability |
| `last_error` JSON metadata bag vs real columns | Tech debt |
| Player UI-only commits (`9bf7ff5`) | Not catalogue sync |
| Usage pulse / Pro copy / ads / FCM extras | Product extras |
| Fly vs Render hosting choice | Ops; not resolver logic |
| Runtime `data/catalog_*.json` dirty files | Cache only — leave uncommitted |

---

## 4. Database sync isolation plan (boundary only — no migration)

```
┌─────────────────────────────────────────────────────────┐
│  LAYER A — JioSaavn live path (MUST stay stable)         │
│  parse_url → preview → resolve → items cache → play      │
│  Admin create/update/delete/refresh operate here first   │
└───────────────────────────┬─────────────────────────────┘
                            │ write-through (async OK)
                            ▼
┌─────────────────────────────────────────────────────────┐
│  LAYER B — Membership (Supabase catalog_sections)        │
│  Truth for: keys, order, group, language, URLs, types    │
│  Writer lease = local authority window on mutating node  │
│  Prune/reconcile = GC only OUTSIDE lease                 │
│  DB failure MUST NOT wipe Layer A preview/resolve result │
└───────────────────────────┬─────────────────────────────┘
                            │ optional later
                            ▼
┌─────────────────────────────────────────────────────────┐
│  LAYER C — Durable track mirror / sync jobs (SEPARATE)   │
│  catalog_section_tracks + catalog_sync_jobs              │
│  Never prune membership; never replace Jio on failure    │
│  Ship behind flag; migration only after approval         │
└─────────────────────────────────────────────────────────┘
```

**Hard rules**  
1. A Supabase outage must not return empty/fake tracks in place of a good Jio resolve.  
2. Refresh stamps `last_refresh` only after successful resolve (or show “queued”).  
3. Delete: DB row gone → then clear items cache → then invalidate Flutter.  
4. Do not run durable sync migration until Layer A+B are proven on web + one Android install.

---

## 5. Safe selective restoration plan (approval required before any edit)

**Do not:** reset, force-push, discard WT data JSON, migrate DB, change live hosting, rebuild APK.

**Proposed order after approval:**

1. **Freeze** Layer C (workers/migration) — feature-flag off / no new calls from Admin hot path.  
2. **App RESTORE R1+R2+R8:** honest save verify; admin-only Jio re-resolve flag; tighter cache health.  
3. **App/API pin one API host (R6)** as an explicit ops decision (Render *or* Fly — not both).  
4. **API:** confirm HEAD already keeps `ca14307` + prune gate + remote-first delete + no hardcoded key — no rollback of those.  
5. **Security SEPARATE:** remove client admin key (R7).  
6. **Only then** consider Layer C durable tracks behind flag.

---

## 6. Test plan (web + Android) — after future implementation only

### Web (Vercel / local Chrome against **pinned** API)

| # | Test |
|---|------|
| W1 | Fresh load Home — Made for you paints without 35s red timeout |
| W2 | Admin create playlist URL → preview tracks → Save → Success only if visible in Admin list **and** second browser/incognito Home |
| W3 | Edit title/group/language; clear subtitle/artwork; confirm persist |
| W4 | Delete → gone after reload + second client |
| W5 | Admin Refresh one section → track list changes match Jio (not cache stamp only) |
| W6 | TRACK/SONG shelf plays; playlist/album open play |
| W7 | Invalid Jio URL → honest error, no random trending fill |

### Android (existing install + sideload debug — **no Play upload in this phase**)

| # | Test |
|---|------|
| A1 | Cold start against pinned API — catalogue matches Admin |
| A2 | After Admin delete on web, pull-to-refresh Home removes card (no reinstall) |
| A3 | Play track → notification / next / seek (`a042258` behaviours) |
| A4 | Background → foreground queue intact |
| A5 | Old install disk cache: force refresh path clears deleted shelves |

### API health

| # | Test |
|---|------|
| S1 | `/health` |
| S2 | Create/Update/Delete timing &lt; Flutter timeout with authority active |
| S3 | Kill API process; restart; deleted sections stay gone (Supabase membership) |
| S4 | Simulate Supabase down during preview — preview still returns Jio data if resolve succeeded |

**Never** delete production catalogue rows in automated tests; use throwaway keys.

---

## 7. Risks and unresolved questions

| Risk / question | Impact |
|-----------------|--------|
| Which host is **actually** live for Play users today — Render or Fly? | Wrong pin breaks all clients |
| Has migration `20261109_catalog_durable_sync.sql` been applied to production Supabase? | Must **not** assume; do not run |
| Are Phase D/G workers enabled on Fly/Render CPU? | Can starve catalogue requests |
| Soft verify may already be masking prod save failures | Live users see Success with missing Home |
| Dirty API `data/catalog_*.json` | Local-only; do not commit or discard blindly |
| Gemini’s 12 suggestions | **Not applied**; this report supersedes blind adoption |
| Is Nov 4 `5ba2b97` “better” overall? | No — worse delete durability; use surgical RESTORE list |

---

## 8. Delivery checklist (this document)

| Deliverable | Status |
|-------------|--------|
| Exact Nov baseline + parents | Done (§1) |
| Exact latest commits | Done (§1) |
| File-by-file comparison | Done (§2) |
| Regressions with evidence | Done (§3 B) |
| Changes to preserve (KEEP) | Done (§3 A) |
| Selective restoration plan | Done (§5) |
| DB sync isolation plan | Done (§4) |
| Web/Android test plan | Done (§6) |
| Risks / open questions | Done (§7) |
| Code edited / committed / deployed | **None** |

---

## 9. Wait for approval

**No implementation until you approve.**  

When approving, please specify:  
1. Target live API host (**Render** vs **Fly**).  
2. Whether Layer C (durable sync migration/workers) stays **fully frozen**.  
3. Which RESTORE items (R1–R9) to implement first.
