# Hasura Fork — Strip Down Plan

## Goal
Minimal Hasura: PostgreSQL + GraphQL + 0-or-1 local-file remote schema. Remove everything else.

## Phase 1: Easy removals (no cascading)
- [x] Remove `dc-agents/` directory
- [x] Remove `server/lib/dc-api/` from cabal.project packages list
- [x] Remove telemetry phone-home (`Server/Telemetry.hs`, `Server/Telemetry/`)
- [x] Remove OpenTelemetry (`RQL/DDL/OpenTelemetry.hs`, `RQL/Types/OpenTelemetry.hs`)

## Phase 2: Prometheus/Metrics (19 import sites)
- [ ] Replace Prometheus types with no-ops/stubs
- [ ] Remove `Server/Prometheus.hs`, `Server/Metrics.hs`
- [ ] Update all 19 call sites

## Phase 3: Tracing (69 import sites — biggest job)
- [ ] Replace `MonadTrace` constraint with no-op
- [ ] Stub out Tracing module to just re-export identity monad operations
- [ ] Or: keep Tracing module but make it a no-op (cheaper approach)

## Phase 4: Remote schema lockdown
- [ ] Remove `add_remote_schema` API endpoint
- [ ] Remove `remove_remote_schema` API endpoint  
- [ ] Remove `reload_remote_schema` API endpoint
- [ ] Load 0 or 1 remote schema from env var `HASURA_GRAPHQL_REMOTE_SCHEMA_FILE`
- [ ] If file doesn't exist → 0 remote schemas (no error)
- [ ] If file exists → load it as the single remote schema
- [ ] URL for forwarding from env var `HASURA_GRAPHQL_REMOTE_SCHEMA_URL`

## Phase 5: Console UI
- [ ] Remove remote schema pages from console (if embedded)

## Strategy for Tracing
Since 69 files import Tracing, the safest approach is to keep the Tracing module
but make all operations no-ops. Replace the reporter with a null reporter.
This avoids touching 69 files while still removing the actual overhead.

## Build & Test
After each phase: `cabal build graphql-engine` (takes ~30 min)
Push to GHA and iterate on CI failures.
