# Deploying to Hetzner with Kamal + Postgres accessory

One VPS, two containers (Rails app + Postgres), TLS via Kamal Proxy, nightly
backups to S3-compatible object storage. Right-sized for a single-user app.

## Why this shape

- **CX22** (€4.51/mo, 2 vCPU / 4 GB / 40 GB) runs app + DB comfortably for this
  workload. Upgrade to **CX32** (€5.91/mo, 4 GB/8 GB) for headroom.
- **Kamal 2** gives zero-downtime deploys, built-in TLS, and accessory
  containers for Postgres — all without touching Nginx or systemd.
- **Co-located Postgres** gives <1 ms query latency vs. 20–40 ms over the
  internet to a managed provider. For this app the speed isn't critical,
  but paying for managed adds cost with no benefit.

## One-time Hetzner setup

1. Create a CX22 VPS in your preferred region (Falkenstein `fsn1` for EU,
   Ashburn `ash` for US East, Hillsboro `hil` for US West).
2. Enable **IPv4** + **IPv6** and set **SSH keys**. Disable password login.
3. (Recommended) Enable **VPS snapshots** — €0.0119/GB/mo, one-click rollback.
4. Create a **Hetzner Object Storage** bucket in the same region for backups.
   Note the S3 endpoint, access key, secret key.
5. Point DNS at the VPS:

   ```
   cooking.gilbert.works.   A     <hetzner-vps-ipv4>
   cooking.gilbert.works.   AAAA  <hetzner-vps-ipv6>
   ```

   Wherever `gilbert.works` is hosted (Cloudflare, Route53, etc.), add an A
   record (and AAAA if you have IPv6). If you're behind Cloudflare, set the
   record to **DNS-only** (grey cloud) for the first deploy — Kamal Proxy
   provisions Let's Encrypt certs by HTTP-01 challenge, which Cloudflare's
   proxy interferes with. Once the cert is in place you can re-enable the
   orange cloud if you want.

## One-time local setup

1. Install Kamal: `gem install kamal` (or `bundle add kamal --group=development`
   and use `bundle exec kamal`).
2. Install Docker locally — Kamal builds images on your machine and pushes
   to a registry.
3. Edit Rails credentials and add the two app secrets:

   ```sh
   bin/rails credentials:edit
   ```

   Add (the hash comes from `ruby -r bcrypt -e 'puts BCrypt::Password.create("your-password").to_s'`):

   ```yaml
   app_password_hash: "$2a$12$....."
   anthropic_api_key: "sk-ant-..."
   ```

   Save. The encrypted file is committed; the master key in `config/master.key`
   stays local. The app reads both values via `Rails.application.credentials`.

4. Fill in the remaining placeholders in `config/deploy.yml`:
   - `<dockerhub-user>` — your Docker Hub username (or swap to `ghcr.io/<user>`)
   - `<hetzner-vps-ip>` — the VPS public IP

   The host (`cooking.gilbert.works`) is already set.

5. Copy `.kamal/secrets` → `.kamal/secrets.local` and fill it in
   (`KAMAL_REGISTRY_PASSWORD`, `POSTGRES_PASSWORD`). The local copy is
   gitignored. `RAILS_MASTER_KEY` is read from `config/master.key`
   automatically.

   If you want Langfuse traces for recipe imports, also add:

   ```sh
   LANGFUSE_PUBLIC_KEY=pk-lf-...
   LANGFUSE_SECRET_KEY=sk-lf-...
   # Optional for self-hosted Langfuse; defaults to cloud.langfuse.com
   LANGFUSE_HOST=https://cloud.langfuse.com
   ```

## First deploy

```sh
set -a; source .kamal/secrets.local; set +a

bin/kamal setup      # installs Docker on the VPS, starts kamal-proxy, boots db, boots web
```

Subsequent deploys:

```sh
bin/kamal deploy
```

Useful operator commands:

```sh
bin/kamal app logs -f                       # tail app logs
bin/kamal accessory logs db -f              # tail postgres logs
bin/kamal app exec -i "bin/rails console"   # console on production
bin/kamal accessory exec db "psql -U cookery cookery_notes_production"
```

## Backups

`bin/backup` dumps the database and uploads it to the configured S3 endpoint
with daily + weekly retention. Three ways to run it:

### Cron on the VPS (recommended)

SSH to the VPS and add a root crontab entry that shells into the app container:

```cron
15 3 * * * docker exec cookery-notes-web bin/backup >> /var/log/cookery-backup.log 2>&1
```

### Kamal one-shot

```sh
bin/kamal app exec "bin/backup"
```

### Restore

```sh
bin/kamal app exec -i "bin/restore"          # lists recent dumps
bin/kamal app exec -i "bin/restore latest"   # restore newest (prompts first)
```

The restore script drops and recreates `public`, then runs `pg_restore`. It
uses the same `DATABASE_URL` the app sees, so it targets the production DB
running in the `db` accessory.

## Verify you can actually recover

**Schedule a monthly restore drill.** A backup you haven't restored from is
a hope, not a plan. The cheapest drill:

1. `bin/kamal accessory exec db "createdb -U cookery cookery_restore_test"`
2. Run `bin/restore latest` against a temporary `DATABASE_URL` pointing at
   `cookery_restore_test`.
3. Spot-check row counts. Drop the test DB.

## Scaling notes

- **Vertical first**: CX22 → CX32 → CX42 (€12.49/mo, 8 vCPU / 16 GB) covers
  virtually anything this app will throw at it.
- **Split DB onto its own VPS** only if the single box is memory-starved.
  Move the `db` accessory to a second host in `config/deploy.yml`; attach
  both VPSes to a free Hetzner Cloud **private network** so Postgres never
  touches the public internet.
- **HA / replication**: if you ever need it, switch to **Neon** (Frankfurt,
  0.5 ms from Hetzner FSN1, $25/mo) rather than operating streaming
  replication yourself.

## What NOT to do

- Don't bind Postgres to `0.0.0.0`. The accessory stanza uses
  `127.0.0.1:5432:5432` — only the app container (on the shared Docker
  network) can reach it.
- Don't run migrations against a Supabase-style transaction pooler — we're
  not using one. If you ever migrate to Neon/Supabase, point migrations at
  the direct port, not the pooler.
- Don't rely on VPS snapshots alone — they cover hardware failure, not
  accidental `DROP TABLE`. Keep the pg_dump pipeline.
