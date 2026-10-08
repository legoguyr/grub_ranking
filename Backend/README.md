# Private cloud schema foundation

No hosted project or credentials are configured. schema.sql is an unapplied first-install design; it is intentionally not named as a Supabase CLI migration. When an approved project/config is added, use the installed CLI's migration workflow to create a tracked migration and apply/review this schema in a disposable development project first. Do not paste it into production or reinterpret existing user stores.

The schema requires Supabase's auth.users/auth.uid and authenticated role. It places application objects in an unexposed staygrubby schema. Enable RLS and explicit API permissions together during Phase 3C; schema creation is not equivalent to API exposure. No direct client writes are granted. Atomic mutation/import/snapshot/account-bootstrap RPCs, real provider/session validation, active-parent deletion rules and hosted integration remain Phase 3C. No social tables, Storage buckets, photo transfer or ranking engine run on the server.

UUID primary keys are account-scoped. Domain dates use Swift reference-date Double seconds; server timestamps/versions are separate. Source preserves seven raw types and every nullable legacy field. Legacy Free and Contains keys remain separate. Comparison endpoint/winner constraints retain repeated UUID observations and fractional ties. Ownership, stable entity identities and observation content cannot be reassigned by ordinary updates. Client writes cannot forge server versions/receipts because they are denied entirely until narrowly authorized RPCs exist.

Minimal profiles are private/owner-only. Username uniqueness is prepared, but username changes, old-handle history, reservations and recycling are deliberately undecided.

## Isolated SQL tests

In tests, run `npm ci --ignore-scripts` and `npm test`. The pinned dependency is PostgreSQL WASM (PGlite); no server, credentials or Supabase project is required. Auth SQL stubs emulate only the UID claim boundary, never real token validation. Tests cover account/auth separation, owner reads, unauthorized reads/writes, private identity mappings, empty/anonymous actors, uniqueness, cross-account evidence, self comparisons, tie constraints, repeated observations, immutable evidence/owners, server versions, tag-kind compatibility, username case uniqueness and deletion-status access revocation. Real Auth/PostgREST/Storage deployment tests must follow in Phase 3C.
