# Deploying to OVH with Kamal

> **As built (2026-10-09):** first successful deploy. Read this before touching
> deployment again — three of the gotchas below each cost a full deploy iteration.

## Server

- OVH VPS `vps-640cbbd1.vps.ovh.net`, IP `51.89.149.82`, user `ubuntu` (root SSH is disabled).
- Ubuntu 26.04, ~38 GB disk. Docker is installed on the server by `kamal setup`.

## One-time prerequisites (local)

1. **SSH key** authorized on the server: `ssh-copy-id -i ~/.ssh/id_ed25519.pub ubuntu@51.89.149.82`
   (or paste the key via the OVH console). Kamal needs *passwordless* SSH — it can't
   answer a password prompt (fails with `Errno::ENOTTY`).
2. **Local user in the `docker` group:** `sudo usermod -aG docker $USER`, then re-login
   (or `newgrp docker`). Otherwise `docker buildx` fails with "permission denied …
   /var/run/docker.sock".
3. **Local Docker daemon running:** `sudo systemctl start docker`.
4. **GHCR classic PAT** exported: `export KAMAL_REGISTRY_PASSWORD=ghp_…` — a *classic* token
   with `write:packages` (fine-grained tokens are not accepted by GHCR).
5. **DNS:** `A` record `viegli-rekini.lv → 51.89.149.82` (needed for Let's Encrypt via the
   Kamal proxy).

## Commands

```bash
bin/kamal setup    # first time only — installs Docker on server, creates volume, loads secrets
bin/kamal deploy   # build locally → push to ghcr.io → pull + boot on server
bin/kamal logs     # tail app logs
bin/kamal app exec -i bin/rails console
bin/kamal app exec -i bin/rails db:seed   # seed the demo tenant (idempotent) — once, post-deploy
```

## OVH-specific config

`config/deploy.yml`:

- `ssh: { user: ubuntu }` — OVH Ubuntu VPSs disable root SSH.
- `image: ghcr.io/ikass/viegli-rekini` (lowercase), registry `ghcr.io`, user `Ikass`.
- `proxy: { ssl: true, host: viegli-rekini.lv }` — HTTPS via kamal-proxy / Let's Encrypt.
- `volumes: ["viegli_rekini_storage:/rails/storage"]` — this volume is where
  `storage/production.sqlite3` lives, so **the DB persists across deploys**.

## Gotchas (each cost an iteration)

1. **`env/clear` must be a hash.** An empty `clear:` (only comments) fails with
   `env/clear: should be a hash`. Omit `clear:` entirely unless there's a real var.
2. **Host authorization blocks the health check.** kamal-proxy probes `/up` with the
   container's internal Host header (e.g. `a6e2cd11046f:80`), which isn't in `config.hosts`,
   so it 403s and the container never becomes "healthy" → Kamal rolls back. The fix is
   `config.host_authorization = { exclude: ->(request) { request.path == "/up" } }`.
3. **Backups are not set up.** Litestream → R2 is still planned. Interim: `sqlite3 .backup`
   or `VACUUM INTO` — never `tar` the live SQLite file.

## Rollback / diagnose

- `bin/kamal rollback <version>` or `bin/kamal rollback` (previous release).
- `bin/kamal details` — container health/state.
- `bin/kamal app exec -i bin/rails dbconsole` — inspect the DB.
