![Hasura logo](./assets/hasura_logo_primary_darkbg.png#gh-dark-mode-only)
![Hasura logo](./assets/hasura_logo_primary_lightbg.png#gh-light-mode-only)

# Hasura GraphQL Engine

The Hasura engine is an open source project which supercharges the building of modern applications by providing access
to data via a single, composable, secure API endpoint.

<a href="https://hasura.io/"><img src="https://img.shields.io/badge/🏠_Visit-Hasura_Homepage-blue.svg?style=flat"></a>
<a href="https://hasura.io/community/"><img src="https://img.shields.io/badge/😊_Join-Community-blue.svg?style=flat"></a>

## Hasura V3

[![Docs](https://img.shields.io/badge/docs-v3-yellow.svg?style=flat)](https://hasura.io/docs/3.0/getting-started/quickstart/)

The future of data delivery is GA: Supporting PostgreSQL (and its flavors), MongoDB, ClickHouse, and MS SQL Server. Also supports writing custom business logic using the Typescript, Python, and Go Connector SDKs. Here is the recommended [Getting Started](https://hasura.io/docs/3.0/getting-started/quickstart/) guide on DDN.

The Hasura v3 engine code, which powers Hasura DDN, is in the `v3` folder of this repo. You can find more detailed
information about in this [v3 README](/v3/README.md).

The Hasura DDN architecture includes Data Connectors to connect to data sources. All Hasura connectors are also
available completely open source. Check out the [Connector Hub](https://hasura.io/connectors/) which lists all
available connectors.

## Hasura V2

[![Latest release](https://img.shields.io/github/v/release/hasura/graphql-engine)](https://github.com/hasura/graphql-engine/releases/latest)
[![Docs](https://img.shields.io/badge/docs-v2.x-yellow.svg?style=flat)](https://hasura.io/docs)

Hasura V2 is the current stable version of the Hasura GraphQL Engine. Please find more
detailed information about the V2 Hasura Graphql Engine in the `v2` folder and this [README](V2-README.md).

## Cloning repository

This repository is a large and active mono-repo containing many parts of the Hasura ecosystem and a long git
history, that can make the first time cloning of the repository slow and consume a lot of disk space. We recommend
following if you are facing cloning issues.

### Shallow clone

This will only clone the latest commit and ignore all historical commits.

```
git clone https://github.com/hasura/graphql-engine.git --depth 1
```

### Git checkout with only Hasura V3 engine code

```
git clone --no-checkout https://github.com/hasura/graphql-engine.git --depth 1
cd graphql-engine
git sparse-checkout init --cone
git sparse-checkout set v3
git checkout @
```

This checkouts the top level files and only the `v3` folder which contains the Hasura V3 Engine code.

## Support & Troubleshooting

To troubleshoot most issues, check out our documentation and community resources. If you have encountered a bug or need
to get in touch with us, you can contact us using one of the following channels:

- Hasura DDN documentation: [DDN docs](https://hasura.io/docs/3.0/)
- Hasura V2 documentation: [V2 docs](https://hasura.io/docs/)
- Support & feedback: [Discord](https://discord.gg/hasura)
- Issue & bug tracking: [GitHub issues](https://github.com/hasura/graphql-engine/issues)
- Follow product updates: [@HasuraHQ](https://twitter.com/hasurahq)
- Talk to us on our [website chat](https://hasura.io)

## Code of Conduct

We are committed to fostering an open and welcoming environment in the community. Please see the
[Code of Conduct](code-of-conduct.md).

## Security

If you want to report a security issue, please [read this](SECURITY.md).

## Stay up to date

Join our communities to stay up to date on announcements, events, product updates, and technical blogs.
[https://hasura.io/community/](https://hasura.io/community/)

## Contributing

Check out our [contributing guide](CONTRIBUTING.md) for more details.

## Brand assets

Hasura brand assets (logos, the Hasura mascot, powered by badges etc.) can be found in the
[v2/assets/brand](assets/brand) folder. Feel free to use them in your application/website etc. We'd be thrilled if you
add the "Powered by Hasura" badge to your applications built using Hasura. ❤️

## Fork: Remote Schema File Support

> **This fork** (`binary64/graphql-engine`) adds support for loading remote schema introspection from a local JSON file instead of performing live HTTP introspection at startup. This eliminates the ~2 GB memory spike that occurs when Hasura introspects a large remote schema.

### Why this exists

Introspecting a large remote GraphQL API (e.g. 20,000+ types) causes Hasura to spike to ~2 GB RSS during startup as it parses the response. By providing a pre-fetched introspection JSON file on disk, Hasura can load the schema without the HTTP round-trip — RSS stays ~76 MB at startup.

Additional benefits:
- **No remote dependency at startup** — Hasura boots even if the remote service is down
- **Deterministic schema** — bake the introspection file into your container image for reproducible builds
- **Faster startup** — eliminates the introspection HTTP round-trip for large schemas
- **No introspection timeout** — works for schemas that would time out during HTTP introspection

### File format

The schema file must contain a standard GraphQL introspection JSON response — the same format returned by a `POST /graphql` with an introspection query:

```json
{
  "data": {
    "__schema": {
      "queryType": { "name": "Query" },
      "mutationType": { "name": "Mutation" },
      "subscriptionType": null,
      "types": [
        { "kind": "OBJECT", "name": "Query", ... },
        ...
      ],
      "directives": [...]
    }
  }
}
```

### Usage 1: `schema_file` field in `add_remote_schema` metadata

Add a `schema_file` field to the `definition` object when calling the `add_remote_schema` metadata API:

```json
{
  "type": "add_remote_schema",
  "args": {
    "name": "my_remote_api",
    "definition": {
      "url": "https://api.example.com/graphql",
      "schema_file": "/etc/hasura/schemas/my_remote_api.json"
    }
  }
}
```

- The `url` field is still **required** — it is used for query forwarding at runtime
- `schema_file` is **optional** — when omitted, Hasura falls back to live HTTP introspection
- The path is resolved on the Hasura server's filesystem (e.g. mount it via a ConfigMap or Docker volume)

### Usage 2: `HASURA_GRAPHQL_REMOTE_SCHEMA_FILE` environment variable

Set this environment variable to a file path as a global fallback for all remote schemas that do not have `schema_file` set in their metadata:

```bash
HASURA_GRAPHQL_REMOTE_SCHEMA_FILE=/etc/hasura/schemas/remote_schema.json
```

**Priority order** (highest wins):
1. `schema_file` in the remote schema's metadata definition
2. `HASURA_GRAPHQL_REMOTE_SCHEMA_FILE` environment variable
3. Live HTTP introspection (default upstream behaviour)

This is useful when running with a single remote schema and you want to configure the file path at deployment time without touching metadata.

### Generating the introspection file

Use a standard introspection query to pre-fetch and save the schema to a file:

```bash
curl -s -X POST https://api.example.com/graphql \
  -H "Content-Type: application/json" \
  -d '{
    "query": "query IntrospectionQuery { __schema { queryType { name } mutationType { name } subscriptionType { name } types { ...FullType } directives { name description locations args { ...InputValue } } } } fragment FullType on __Type { kind name description fields(includeDeprecated: true) { name description args { ...InputValue } type { ...TypeRef } isDeprecated deprecationReason } inputFields { ...InputValue } interfaces { ...TypeRef } enumValues(includeDeprecated: true) { name description isDeprecated deprecationReason } possibleTypes { ...TypeRef } } fragment InputValue on __InputValue { name description type { ...TypeRef } defaultValue } fragment TypeRef on __Type { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name ofType { kind name } } } } } } }"
  }' \
  > /etc/hasura/schemas/my_remote_api.json
```

Verify the file starts with `{"data":{"__schema":{` — that's the correct format.

### Kubernetes / Docker example

Mount the schema file as a ConfigMap volume and reference it in the `add_remote_schema` call:

```yaml
# ConfigMap containing the introspection JSON
apiVersion: v1
kind: ConfigMap
metadata:
  name: remote-schemas
data:
  my_api.json: |
    {"data": {"__schema": { ... }}}

---
# Hasura Deployment
spec:
  containers:
  - name: hasura
    image: ghcr.io/binary64/graphql-engine:feat-hasura-lean-schema
    volumeMounts:
    - name: schemas
      mountPath: /etc/hasura/schemas
  volumes:
  - name: schemas
    configMap:
      name: remote-schemas
```

Then in your Hasura metadata:

```json
{
  "type": "add_remote_schema",
  "args": {
    "name": "my_api",
    "definition": {
      "url": "https://my-api.internal/graphql",
      "schema_file": "/etc/hasura/schemas/my_api.json"
    }
  }
}
```

### Docker image

Pre-built images for this fork are available from GHCR:

```bash
docker pull ghcr.io/binary64/graphql-engine:feat-hasura-lean-schema
```

---

## Licenses

### V3

All the [Data Connectors](https://github.com/hasura/ndc-hub) are available under
the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0).

The core [V3 GraphQL Engine](v3/) is intended to be licensed under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) (Apache-2.0).

### V2

The V2 core GraphQL Engine is available under the [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) (Apache-2.0).

All **other contents** in the v2 folder (except those in [`server`](v2/server), [`cli`](v2/cli) and
[`console`](v2/console) directories) are available under the [MIT License](LICENSE-community).
This includes everything in the [`docs`](v2/docs) and [`community`](v2/community)
directories.
