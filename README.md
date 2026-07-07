# iKeep

A private, self-hostable archive for your iMessage history. iKeep ingests
the output of [imessage-exporter](https://github.com/ReagentX/imessage-exporter)
(or a snapshot copy of `chat.db`) into its own SQLite databases, then lets
you browse and search it like Messages — including natural-language
semantic search and question answering powered by a **local** LLM (Ollama).
Your messages never leave your machines.

iKeep is strictly read-only over source data: it never writes to, mutates,
or deletes the exported files or the original iMessage database. And once
your history is safely archived, you can tell your iPhone to keep only
recent messages — reclaiming gigabytes — because the full history lives
here.

## What you get

* **Chat list** like Messages: pinned search bar, favorites strip (max 6,
  drag to reorder), conversations by recency with decrypted snippets.
* **Threads** with bubbles (yours right and blue), attachment chips, and
  succinct human timestamps; infinite backwards pagination via Turbo.
* **Hybrid search**: keyword (decrypted in-app — encrypted bodies can't be
  matched in SQL) plus semantic nearest-neighbors via sqlite-vec.
* **Ask mode**: retrieval-augmented answers from a local model, citing the
  messages it used. Generation is optional; search works without it.
* **Encryption at rest** for message bodies and attachment paths
  (ActiveRecord::Encryption, non-deterministic).
* **Database-per-tenant**: each tenant is one SQLite file in WAL mode.
  Export a tenant = copy a file. Delete a tenant = delete a file.
* **iOS app**: a Hotwire Native shell in `ios/` wraps the web app.

## Requirements

* macOS on Apple Silicon (any Unix works for the server part)
* Ruby (version in `.ruby-version`; install via `rbenv` or `mise`)
* [Ollama](https://ollama.com) running locally for semantic search/Ask:

      brew install ollama
      ollama pull nomic-embed-text     # embeddings, 768 dims
      ollama pull llama3.1:8b          # generation (optional)

## Setup

```sh
git clone <this repo> && cd ikeep
bundle install
bin/rails db:prepare db:seed   # app DB + the single "default" tenant
bin/rails test                 # everything should be green
bin/rails server               # http://localhost:3000
```

## From iPhone to archive (the full journey)

The goal: every message safely in iKeep, verified, and your iPhone freed
to forget the old ones.

**1. Get your history onto your Mac.**
Turn on Messages in iCloud on both iPhone and Mac (Settings → [your name]
→ iCloud → Messages / on the Mac: Messages → Settings → iMessage → Enable
Messages in iCloud) and let it finish syncing. Your full history is then
in `~/Library/Messages/chat.db` on the Mac.

**2. Export.** Two options, both safe:

* **imessage-exporter (recommended):**

      brew install imessage-exporter
      imessage-exporter -f txt -o ~/imessage-export -c full -a ~/imessage-export/attachments

  Give your terminal Full Disk Access first (System Settings → Privacy &
  Security → Full Disk Access), and quit Messages while exporting.

* **Snapshot chat.db** (uses SQLite's own backup so the live DB is never
  touched mid-write; iKeep refuses to open the live file):

      sqlite3 ~/Library/Messages/chat.db ".backup '$HOME/imessage-snapshot/chat.db'"

**3. Import into iKeep.** Idempotent — run it as often as you like, only
new messages are added:

```sh
bin/rails archive:import SOURCE=~/imessage-export      # exporter output
bin/rails archive:import SOURCE=~/imessage-snapshot/chat.db   # or the snapshot
```

Attachments stay where the exporter put them (an external drive is a fine
home); iKeep stores their paths encrypted.

**4. Embed for semantic search** (Ollama must be running — `ollama serve`
or the menu bar app). Batched, resumable, idempotent:

```sh
bin/rails embeddings:backfill
```

**5. Verify before you delete anything.** Open the app, spot-check your
oldest conversations, search for things you remember, and confirm counts
look right. Then back up the archive itself — it's one file:

```sh
cp storage/tenants/production/default.sqlite3 /Volumes/Backup/ikeep-$(date +%F).sqlite3
```

**6. Reclaim your iPhone's space.** This is the Apple-native step iKeep
deliberately does not automate. On the iPhone:

> **Settings → Apps → Messages → Keep Messages → 30 Days** (or 1 Year)

Confirm when iOS offers to delete older messages. Two honest warnings:

* With Messages in iCloud on, this setting applies to **all your
  devices** — the old messages disappear from iCloud and every synced
  device. After this, **iKeep is your only copy**. That's the point, but
  make sure step 5 happened first.
* Large attachments can also be pruned selectively via Settings →
  General → iPhone Storage → Messages.

**7. Repeat on a schedule.** Export + import (steps 2–4) monthly, or at
least more often than your Keep Messages window, so nothing ages out
before it's archived. Imports only ever add.

## Deployment (self_host)

iKeep is meant to run on a Mac (or any box) you own, reachable only over
your private network. **Do not expose it to the public internet — it has
no authentication.** Tailscale is the recommended transport.

```sh
# one-time production setup
export RAILS_ENV=production
export IKEEP_ENCRYPTION_SECRET=$(openssl rand -hex 32)   # store in a password manager!
bin/rails db:prepare db:seed

# run it
bin/rails server -p 3000

# private HTTPS via Tailscale (install from tailscale.com, then):
tailscale serve --bg 3000
# → https://your-mac.your-tailnet.ts.net, visible only inside your tailnet
```

Keep the server alive across reboots with a `launchd` agent, e.g.
`~/Library/LaunchAgents/com.ikeep.server.plist` running
`bin/rails server -e production` from the app directory (set
`RAILS_MASTER_KEY`/`IKEEP_ENCRYPTION_SECRET` in the plist's
`EnvironmentVariables`), or just a `tmux` session if you prefer.

**Losing `IKEEP_ENCRYPTION_SECRET` means losing the archive** — bodies
are encrypted with it. Store it (and `config/master.key`) somewhere that
survives the machine: password manager or the macOS Keychain
(`security add-generic-password -s ikeep -a encryption -w <secret>`, then
inject it at boot).

### Environment reference

| Variable | Default | Purpose |
| --- | --- | --- |
| `DEPLOYMENT_MODE` | `self_host` | `self_host` or `hosted` |
| `IKEEP_ENCRYPTION_SECRET` | dev/test derive one | Host encryption key (required in production self_host) |
| `IKEEP_KEY_DERIVATION_SALT` | derived | Salt for key derivation |
| `OLLAMA_URL` | `http://localhost:11434` | Local Ollama endpoint |
| `EMBED_MODEL` | `nomic-embed-text` | Embedding model (768 dims) |
| `GEN_MODEL` | `llama3.1:8b` | Generation model; `""` disables Ask (qwen2.5:7b also works) |
| `TENANT` | `default` | Tenant for rake tasks |

## Hosted mode (multi-tenant)

`DEPLOYMENT_MODE=hosted` serves many tenants: each request is routed by
subdomain (`alpha.ikeep.example` → tenant `alpha`), every tenant is its
own SQLite file with its own server-held encryption key.

```sh
bin/rails tenants:provision NAME=alpha
bin/rails tenants:list
bin/rails tenants:delete NAME=alpha      # deletes exactly one file
```

**The honest privacy guarantee.** Host-side semantic search requires the
host to decrypt messages, so hosted mode is *convenience-grade*
encryption: it protects against disk theft and cross-tenant leaks, but
the operator *can* decrypt tenant data. It is **not** zero-knowledge. If
you don't operate the server, you're trusting whoever does. self_host
mode has the same mechanics but you are the operator, on your own
hardware, behind your own tailnet — that's the configuration iKeep is
built for.

Future hardening, deliberately left open:

* The `Tenant::KeyProvider` seam is where a zero-knowledge,
  client-held-key mode would plug in (out of scope for v1).
* [SQLCipher](https://www.zetetic.net/sqlcipher/) can add full-file
  encryption on top of the per-attribute encryption.

## iOS app

See [`ios/README.md`](ios/README.md): a Hotwire Native shell you build in
Xcode in about five minutes, pointed at your tailnet URL.

## Architecture notes

* The shared app database holds only the tenant registry — names and
  (hosted mode) keys, never message content.
* Tenant models inherit `TenantRecord`, reachable only inside
  `Tenant#switch`; every request is wrapped in a switch, and touching
  tenant data outside one raises.
* Vectors live in a `message_embeddings` vec0 table (sqlite-vec, cosine,
  brute-force KNN — plenty under 100k messages).
* Import funnels through `Archive.record`, deduplicated on `Message#guid`,
  so re-imports are no-ops.
