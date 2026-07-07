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
look right. Then back up the archive itself — it's one file (the same
path whether you run natively or under Compose, since `storage/` is
bind-mounted):

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

## Self-hosting on a Mac mini

iKeep is meant to run on a box you own — here: a Mac mini — reachable
only over your private network, administered from any laptop (say, a T14
ThinkPad) over Tailscale SSH. **Do not expose it to the public internet —
it has no authentication.** The tailnet is the perimeter.

### 0. Wire up the tailnet and SSH in

On the mini (one time, at the machine or via Screen Sharing):

1. Install [Tailscale](https://tailscale.com/download) and sign in.
2. Turn on Remote Login: System Settings → General → Sharing → Remote
   Login. (Or let Tailscale handle auth entirely: `tailscale set --ssh`.)

On the ThinkPad: install Tailscale, join the same tailnet, and from then
on everything in this guide happens inside one SSH session:

```sh
ssh you@mini.your-tailnet.ts.net
```

One macOS gotcha worth knowing up front: reading `~/Library/Messages/`
(the export step) requires Full Disk Access, and SSH sessions get it from
the sshd entry, not your terminal app. Grant it once at System Settings →
Privacy & Security → Full Disk Access → enable **sshd-keygen-wrapper**
(it appears in the list after your first SSH attempt to touch a protected
file).

### 1. Generate the secrets (once, either path)

```sh
mkdir -p ~/ikeep && cd ~/ikeep && git clone <this repo> app && cd app
cat > .env <<EOF
SECRET_KEY_BASE=$(openssl rand -hex 64)
IKEEP_ENCRYPTION_SECRET=$(openssl rand -hex 32)
IKEEP_KEY_DERIVATION_SALT=$(openssl rand -hex 32)
EOF
chmod 600 .env
```

**Copy `.env` into your password manager now.** Losing
`IKEEP_ENCRYPTION_SECRET` (or the salt) means losing the archive —
message bodies are encrypted with keys derived from them. The `.env`
file is gitignored and read by both setups below.

### 2a. Docker Compose (simplest to operate)

Install [Docker Desktop for Mac](https://docs.docker.com/desktop/setup/install/mac-install/)
(or [OrbStack](https://orbstack.dev), which runs headless more happily)
and [Ollama](https://ollama.com) — Ollama runs **natively**, not in the
container, because macOS containers can't reach the GPU:

```sh
brew install ollama
brew services start ollama          # survives reboots
ollama pull nomic-embed-text && ollama pull llama3.1:8b

docker compose up -d --build        # first boot migrates and seeds the default tenant
curl -s http://localhost:3000/up    # → 200
```

Tenant databases live in `./storage` on the host (bind-mounted), so
`docker compose down` and image rebuilds never touch your data. Import
and embed by mounting the export into a one-off container:

```sh
docker compose run --rm -v "$HOME/imessage-export:/import:ro" ikeep \
  bin/rails archive:import SOURCE=/import
docker compose run --rm ikeep bin/rails embeddings:backfill
```

The commented-out `ollama` service in `compose.yml` is for Linux hosts,
where a containerized Ollama can still use the GPU.

### 2b. Native (no Docker, Metal-fast Ollama, launchd-managed)

```sh
brew install rbenv ruby-build ollama
rbenv install $(cat .ruby-version)
bundle install
brew services start ollama
ollama pull nomic-embed-text && ollama pull llama3.1:8b

set -a; source .env; set +a
RAILS_ENV=production bin/rails db:prepare db:seed
RAILS_ENV=production bin/rails server   # smoke test, then Ctrl-C
```

Keep it alive across reboots with a launchd agent. Write
`~/Library/LaunchAgents/com.ikeep.server.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>Label</key><string>com.ikeep.server</string>
  <key>WorkingDirectory</key><string>/Users/you/ikeep/app</string>
  <key>ProgramArguments</key>
  <array>
    <string>/bin/bash</string><string>-lc</string>
    <string>set -a; source .env; set +a; exec bin/rails server -e production</string>
  </array>
  <key>RunAtLoad</key><true/>
  <key>KeepAlive</key><true/>
  <key>StandardOutPath</key><string>/Users/you/ikeep/server.log</string>
  <key>StandardErrorPath</key><string>/Users/you/ikeep/server.log</string>
</dict></plist>
```

```sh
launchctl load ~/Library/LaunchAgents/com.ikeep.server.plist
```

Import and embed run in the same directory with the same `.env` loaded:

```sh
set -a; source .env; set +a
RAILS_ENV=production bin/rails archive:import SOURCE=~/imessage-export
RAILS_ENV=production bin/rails embeddings:backfill
```

### 3. Reach it from everywhere on your tailnet

```sh
tailscale serve --bg 3000
# → https://mini.your-tailnet.ts.net — real HTTPS, tailnet-only
```

That URL works from the ThinkPad's browser, your iPhone (with Tailscale
installed), and is what the iOS shell's `rootURL` should point at. Plain
`http://mini.your-tailnet.ts.net:3000` also works — the tailnet is
already encrypted — which is why the app doesn't force SSL (opt back in
with `IKEEP_FORCE_SSL=true`).

### Environment reference

| Variable | Default | Purpose |
| --- | --- | --- |
| `DEPLOYMENT_MODE` | `self_host` | `self_host` or `hosted` |
| `SECRET_KEY_BASE` | dev/test derive one | Rails secret; required in production |
| `IKEEP_ENCRYPTION_SECRET` | dev/test derive one | Host encryption key (required in production self_host) |
| `IKEEP_KEY_DERIVATION_SALT` | derived from secret_key_base | Salt for key derivation — set it explicitly in production |
| `IKEEP_FORCE_SSL` | `false` | Redirect all traffic to HTTPS inside the app |
| `OLLAMA_URL` | `http://localhost:11434` | Local Ollama endpoint (`http://host.docker.internal:11434` under Compose) |
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
