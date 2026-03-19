# Multi-stage build for Hasura GraphQL Engine (memory-optimized fork)
# Stage 1: Build with GHC 9.10
FROM haskell:9.10.3-slim-bookworm AS builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq-dev \
    libssl-dev \
    libpcre3-dev \
    pkg-config \
    zlib1g-dev \
    libgmp-dev \
    unixodbc-dev \
    curl \
    git \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

WORKDIR /build

# Copy cabal config first for dependency caching
COPY cabal.project cabal.project
COPY cabal/dev-sh.project cabal/dev-sh.project
COPY cabal/dev-sh.project.local cabal/dev-sh.project.local
COPY server/graphql-engine.cabal server/graphql-engine.cabal
COPY server/lib/ server/lib/

# Create a production cabal.project.local
RUN cat > cabal.project.local << 'CABALEOF'
import: cabal/dev-sh.project.local

-- Static Haskell libs, dynamic C libs only
executable-dynamic: False
library-vanilla: True

package *
  ghc-options: -j1 +RTS -A64m -n2m -M6500m -RTS -Wno-error=unused-packages

package hedis
  library-vanilla: True
package Spock
  library-vanilla: True
package hasql-pool
  library-vanilla: True

-- Allow newer hashtables
allow-newer: hashtables

-- Production: no debug, no coverage
package graphql-engine
  coverage: false
  ghc-options: -O1

flags: -optimize-hasura
CABALEOF

# Copy everything else
COPY . .

# Remove freeze file — it's pinned to GHC 9.10.2's base, incompatible with 9.10.3
RUN rm -f cabal.project.freeze

# Remove test packages that depend on dc-agents (excluded from Docker context via .dockerignore)
RUN rm -rf server/lib/api-tests server/lib/test-harness server/lib/upgrade-tests

# Build: fetch deps then compile (single-threaded to keep memory low)
RUN cabal update \
    && cabal build graphql-engine --only-dependencies -j2 \
    && cabal build graphql-engine -j1 \
    && cp $(cabal list-bin graphql-engine) /build/graphql-engine-bin \
    && strip /build/graphql-engine-bin

# Stage 2: Runtime image
FROM debian:bookworm-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libssl3 \
    libpcre3 \
    zlib1g \
    libgmp10 \
    libc6 \
    ca-certificates \
    curl \
    unixodbc \
    libstdc++6 \
    && apt-get clean && rm -rf /var/lib/apt/lists/*

COPY --from=builder /build/graphql-engine-bin /usr/local/bin/graphql-engine

# Non-root user
RUN useradd -m hasura
USER hasura

EXPOSE 8080

HEALTHCHECK --start-period=10s CMD curl -f http://localhost:8080/healthz || exit 1

CMD ["graphql-engine", "serve"]
