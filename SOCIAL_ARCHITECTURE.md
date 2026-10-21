# StayGrubby social architecture

Private cooking history and the social graph are separate. Social APIs never return the CookingGraph, private media paths, Auth identities, email or sync metadata. Social engagement never changes comparisons, strengths, scores, personal ranks or score-unlock eligibility. Existing accounts may keep using private StayGrubby without social setup.

## Identity

Reuse the permanent account and existing profiles table. Display names collapse whitespace, allow nicknames and have a 50-character limit. Usernames trim whitespace/one optional leading @, lowercase, and require 3–24 ASCII letters/numbers with single internal underscores. The existing case-insensitive unique index is authoritative. A small deterministic platform/system-name set is reserved, including underscore variants. Old handles are reserved to their account for 30 days after rename; the same account may reclaim them. Account deletion cascades reservations. No redirects or marketplace.

Discoverability defaults false. Setup is optional; identity edits use an authenticated owner-derived RPC, with no direct client writes. Discoverability controls normal search, not existing friendship identity or private cooking. No avatar/bio system is introduced. Social responses are held in the account-mounted UI, never hydrated into private cooking stores. Account-generation checks discard stale replies after switching/sign-out.

## Verification policy

Compile and focused feature tests at each checkpoint, one Simulator lane. SQL tests use disposable PGlite Auth/session stubs, not real Apple authorization. Hosted checks compare version/name/hash, grants, RLS and non-sensitive private-data fingerprints before/after each migration. Real Apple deletion, physical device tests, full historical ranking/photo/sharing/Cuisine suites and release builds are excluded unless a concrete dependency demands them.

## Mutual friendship and blocks

One canonical unordered UUID pair row holds requester and pending/friends/declined/cancelled/removed state. Pair-scoped transaction locks serialize transitions; live Auth/account checks repeat after lock waits. Same-direction requests are idempotent; crossed eligible requests become friends. Only recipients accept/decline, only senders cancel, either friend removes. A declined sender waits 24 hours before retry; the recipient may initiate a new request. Stale transitions fail with refreshable conflict status.

Directed blocks are a separate private security primitive. Either-direction block suppresses normal social lookup/requests and retires pending/friend state. Only the blocker can remove their block; unblock restores nothing. The blocker's own blocked list may identify users they deliberately blocked. Friendships/blocks/reservations cascade with permanent account deletion. Clients have no direct table writes or raw social-table reads; narrow owner-derived RPCs return minimal social DTOs. Search is username-only, requires 2–50 characters, excludes self, respects discoverability and blocks, and uses 50-row username cursors. Existing friends/requests retain identity access when discoverability is off. Internal peer IDs are opaque action references and are never displayed as profile content.

## Friends UI

Friends is reached from Profile, without a Feed tab. Native lists provide friends, incoming requests, outgoing requests, username search and the caller's blocked list. Search is debounced, keyboard-friendly and excludes undiscoverable/blocked people. Username cursors bound normal lists to 50 rows per response with Load more. Minimal person sheets expose only name, @username, relationship and permitted actions; no private cooking graph, Top 3, email, raw account identifier, allergens or sync metadata. Remove/block use confirmations. Server refresh is authoritative after mutations/stale conflicts; errors clear stale list content and permit retry. Social setup remains optional and does not gate private cooking.

## Safety and content privacy

Friends-only post visibility is enforced in private SQL: author/current eligible friends only, with active accounts/profiles, published/unretired/unhidden content and either-direction blocks applied. Discoverability is independent of existing friendships/content access. No raw social-table grants are provided to clients; every new table has RLS. Profiles/comments/posts have service-controlled active/hidden states. Hidden social identities cannot interact socially but retain private cooking access. The service-only moderation RPC cannot be called by authenticated or anonymous clients. Protected operators can review pending reports in SQL; no admin dashboard, external vendor or AI moderator is added. Operational response procedures remain an owner responsibility before broader distribution.

Reports target a currently accessible profile/post/comment, use six reasons and optional 500-character context, deduplicate by reporter/target, and cap new reports to 50/day. Clients receive only reported=true; targets cannot read raw reporter/context data. Reports do not automatically hide content. Reporter/target-account and post/comment foreign keys provide deletion cleanup without a new retention archive. Profile reporting is available before blocking; inaccessible targets cannot be used to infer private data. Native report UI uses the same boundary. Existing inaccessible-table INFO advisor notices are intentional; see https://supabase.com/docs/guides/database/database-linter?lint=0008_rls_enabled_no_policy. The pre-existing disabled-password warning is unchanged: https://supabase.com/docs/guides/auth/password-security#password-strength-and-leaked-password-protection.
