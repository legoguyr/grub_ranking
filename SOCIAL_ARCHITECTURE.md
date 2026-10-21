# StayGrubby social architecture

Private cooking history and the social graph are separate. Social APIs never return the CookingGraph, private media paths, Auth identities, email or sync metadata. Social engagement never changes comparisons, strengths, scores, personal ranks or score-unlock eligibility. Existing accounts may keep using private StayGrubby without social setup.

## Identity

Reuse the permanent account and existing profiles table. Display names collapse whitespace, allow nicknames and have a 50-character limit. Usernames trim whitespace/one optional leading @, lowercase, and require 3–24 ASCII letters/numbers with single internal underscores. The existing case-insensitive unique index is authoritative. A small deterministic platform/system-name set is reserved, including underscore variants. Old handles are reserved to their account for 30 days after rename; the same account may reclaim them. Account deletion cascades reservations. No redirects or marketplace.

Discoverability defaults false. Setup is optional; identity edits use an authenticated owner-derived RPC, with no direct client writes. Discoverability controls normal search, not existing friendship identity or private cooking. No avatar/bio system is introduced. Social responses are held in the account-mounted UI, never hydrated into private cooking stores. Account-generation checks discard stale replies after switching/sign-out.

## Verification policy

Compile and focused feature tests at each checkpoint, one Simulator lane. SQL tests use disposable PGlite Auth/session stubs, not real Apple authorization. Hosted checks compare version/name/hash, grants, RLS and non-sensitive private-data fingerprints before/after each migration. Real Apple deletion, physical device tests, full historical ranking/photo/sharing/Cuisine suites and release builds are excluded unless a concrete dependency demands them.
