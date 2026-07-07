# iKeep

A private, self-hostable archive for your iMessage history. iKeep ingests the
output of [imessage-exporter](https://github.com/ReagentX/imessage-exporter)
(or a snapshot copy of `chat.db`) into its own SQLite databases, then lets you
browse and search it — including natural-language semantic search powered by a
local LLM (Ollama). Your messages never leave the box.

iKeep is strictly read-only over source data: it never writes to, mutates, or
deletes the exported files or the original iMessage database.

## Architecture

* **One SQLite file per tenant**, under `storage/tenants/<env>/<name>.sqlite3`,
  in WAL mode, with the [sqlite-vec](https://github.com/asg017/sqlite-vec)
  extension loaded for vector search. Exporting or deleting a tenant is
  copying or deleting one file.
* **A small shared app database** holds the tenant registry only — never
  message content.
* Models living in tenant databases inherit from `TenantRecord` and are only
  reachable inside a `Tenant#switch` block; every request is wrapped in one.
  Touching tenant data outside a switch raises.
* In `self_host` mode the app runs exactly one tenant, named `default`.

## Setup

Requires Ruby (see `.ruby-version`) and SQLite 3.

```sh
bundle install
bin/rails db:prepare db:seed   # creates the app DB and the default tenant
bin/rails test
bin/rails server
```

## Roadmap

Phase 1 (done): Rails 8 skeleton, database-per-tenant SQLite in WAL mode,
tenant registry + connection switching, sqlite-vec proven by tests.

Coming next: encrypted message bodies (ActiveRecord::Encryption), idempotent
`archive:import`, iMessage-style Hotwire UI, local embeddings + hybrid
keyword/semantic search via Ollama, Hotwire Native iOS shell, hosted
multi-tenant mode.
