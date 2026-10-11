# Private cloud schema foundation

The hosted StayGrubby project is `lgjxbpycphhsswxoncmz` (PostgreSQL 17). The initial and access-hardening migrations were applied on October 11, 2026 using authenticated Supabase MCP tooling. No privileged credential was requested or stored. See [setup and verification](../supabase/README.md) for exact versions, exposure, results and remaining integration work.

`supabase/migrations/` is the authoritative deployment history. `schema.sql` is a first-install reference that concatenates those migrations; the tests require parity. Never reapply the reference to an existing database or edit an applied migration. Create follow-up migrations using the supported CLI and update the reference alongside them.

The schema requires Supabase's `auth.users`, `auth.uid()` and client roles. Permanent StayGrubby account UUIDs remain separate from Auth identities. All cooking keys and foreign keys include the account owner. Sources preserve seven raw types and every nullable legacy field; Contains and legacy Free tags remain distinct. Cached scores are full-precision data, with no server ranking engine.

All 15 application tables have RLS. Authenticated clients have owner-only SELECT on 14 tables; private Auth links have neither policies nor client privileges. Explicit revocations deny anonymous access and all direct client writes, including RLS-bypassing TRUNCATE. The only authenticated helper execution is the fixed-search-path `current_account_id()` resolver. Neither tables nor helpers are exposed through the hosted Data API.

Soft-deleted rows retain IDs, versions and deletion timestamps as tombstone evidence. Domain parent FKs use deferred NO ACTION; account erasure cascades the full graph, while Auth identity deletion cascades only its link. Atomic deletion/restoration rules, consistent tombstone snapshots, receipt processing and retry retention must be implemented and tested before enabling writes. There is no provisioning, mutation, import or snapshot RPC yet.

Minimal profiles are private/owner-only. Username uniqueness is prepared; username changes, old-handle history, reservations and recycling remain undecided.

## Isolated SQL tests

Run `npm ci --ignore-scripts` and `npm test` in `Backend/tests`. The pinned PostgreSQL WASM dependency is test tooling only. The harness applies the tracked migration chain to a disposable database; Auth stubs emulate the UID claim boundary, never real token validation. Its 40 assertions cover ownership, cross-account constraints, denied writes/link forgery/TRUNCATE, immutable IDs/evidence, versions, tag compatibility, uniqueness, deletion and reference parity.

Hosted catalog/grant checks and unauthenticated REST checks were also performed without creating users. Account A/B tests remain local-equivalent; real Auth/JWT/PostgREST end-to-end tests require later authenticated integration. No guest library, photos or test accounts were uploaded.
