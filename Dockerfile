# Multi-stage build for Hasura GraphQL Engine (memory-optimized fork)
# Stage 1: Build with GHC 9.10.2
FROM haskell:9.10.2-slim AS builder

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

# Copy everything (Hasura has many sub-packages)
COPY . .

# Create a production cabal.project.local
RUN cat > cabal.project.local << 'CABALEOF'
import: cabal/dev-sh.project.local

-- Static Haskell libs, dynamic C libs only
executable-dynamic: False
library-vanilla: True

package *
  ghc-options: -j2 +RTS -A128m -n4m -RTS

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

# Build: fetch deps then compile
RUN cabal new-update \
    && cabal new-build graphql-engine -j2 --only-dependencies \
    && cabal new-build graphql-engine -j1 \
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
