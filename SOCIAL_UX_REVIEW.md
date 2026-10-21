# Social UX enhancement review — October 21, 2026

Baseline: clean `main`, `d8b01a7fe1d9111781c4eb9b1ca2b0ef1440c26d`, aligned with local origin/main. Original Social V1 is retained. Hosted baseline: 16 aligned migrations, two private photo buckets, 24 RLS application tables. Original 12 private count/hash groups match the preceding social review; the simulator demo manifest remains the preservation baseline. No real social users, content or media are used for tests.

## Checkpoint 1 — Profile photo foundation

A dedicated private profile-photos bucket, owner-scoped immutable version paths and draft/publish/remove/cleanup RPC implement optional identity media. Only intended authenticated social audiences can read; blocks apply and listing is denied. Friends/search/request lists, own identity/setup, minimal friend profile, Feed authors and comments use the same circular avatar/initials component. No private cooking-media architecture is reused except its pure image encoder; there are no cooking-media graph/file writes. Account deletion guards and cleans all three buckets, retaining Apple verification/revocation order. See SOCIAL_ARCHITECTURE.md.

Local focused SQL: 29 assertions passed, including draft/upload ownership, unauthorized replacement/removal, discoverability/friends/block visibility, no listing/anonymous access, safe DTOs, immutable replacement, cleanup, deletion guard/cascade and ranking-cache preservation. Synthetic deletion-function tests: 8 passed, including avatar cleanup failure preventing graph/Auth erasure. Native avatar/session tests: 5 passed. Debug build passed. Initial new UI failure identified automatic Form-row button propagation between photo selection/removal; independent borderless controls correct it. Final dark avatar preview/save/remove UI passed 1/1 in `/private/tmp/staygrubby-avatar-ui-final.xcresult`, zero failures/skips. The account/schema checks also passed 82 assertions against the additive migration. Native photo-library selection itself remains for real-device review; the isolated UI test injects synthetic selected bytes into the same preview/save path.

Hosted deployment is pending direct owner approval because automatic approval review rejected attachment-only authorization for the persistent avatar/profile/Storage/deletion migration. No alternate deployment route is used. Later deployment results and exact migration timestamps will be recorded when authorized.

No TestFlight/archive, physical device, real Apple deletion, secret inspection, website publication or App Store Connect work occurred.
