# Deploying to OVH with Kamal

> **As built (2026-10-09), re-deployed (2026-10-11):** read this before touching
> deployment — the gotchas below each cost a full deploy iteration.

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
4. **GHCR classic PAT** — a *classic* token with `write:packages` (fine-grained tokens are
   not accepted by GHCR), kept in a per-machine file. See "New machine setup" below.
5. **DNS:** `A` record `viegli-rekini.lv → 51.89.149.82` (needed for Let's Encrypt via the
   Kamal proxy).

## New machine setup — recreate the two secrets

Deploying from a fresh machine needs two files that are deliberately **not** in git (the
committed `.kamal/secrets` is only a *loader* that reads them at deploy time — no secret
value ever enters the repo):

1. **Rails master key** — `config/master.key` (gitignored). Keep the 32-byte value in your
   password manager; copy it into the repo on each machine:

   ```bash
   printf '%s\n' "<32-byte-master-key>" > config/master.key
   chmod 600 config/master.key
   ```

2. **GHCR token** — a classic PAT with `write:packages`
   (GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)):

   ```bash
   mkdir -p "$HOME/.config/viegli-rekini"
   printf '%s\n' "ghp_..." > "$HOME/.config/viegli-rekini/ghcr-token"
   chmod 600 "$HOME/.config/viegli-rekini/ghcr-token"
   ```

   (Or `export KAMAL_REGISTRY_PASSWORD=ghp_...` as a one-off override — the loader prefers
   the env var over the file.)

## Commands

> After the one-time setup below, `bin/kamal deploy` is the **only** command you run per deploy.
> The secrets, docker group, and daemon are one-time per machine — nothing else needs re-running.

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
- `image: ikass/viegli-rekini` (lowercase, no host), registry `ghcr.io`, user `Ikass`.
  Kamal builds `<server>/<image>` = `ghcr.io/ikass/viegli-rekini`. Putting the host in `image:`
  doubles it to `ghcr.io/ghcr.io/…`.
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
4. **`.kamal/secrets` is parsed by dotenv, not bash.** It supports `$(command)` and `$VAR`,
   but **not** `${VAR:-default}` — a `${VAR:-…}` line resolves to a mangled value (empty
   password → `denied: denied` at `docker login`). Keep secrets to plain `$(cat …)` /
   `$VAR`.
5. **Don't put the host in `image:`.** Kamal prepends `registry.server` to `image`, so
   `image: ghcr.io/ikass/viegli-rekini` + `server: ghcr.io` builds
   `ghcr.io/ghcr.io/ikass/viegli-rekini` (doubled) and the push 403s. Use
   `image: ikass/viegli-rekini` — see "OVH-specific config".
6. **Kamal builds from the committed `HEAD`, not the working tree.** Uncommitted changes are
   silently dropped from the image (the deploy version is the commit SHA). Symptom: you edit
   `Gemfile`/`Gemfile.lock` (or any file), deploy, and the change is mysteriously absent — the
   `COPY Gemfile Gemfile.lock ./` layer shows `CACHED` even though the file changed locally.
   **Commit before you deploy.** (Caught 2026-10-14: Sentry gems "installed" locally but absent
   in the image because they were uncommitted.)

## Rollback / diagnose

- `bin/kamal rollback <version>` or `bin/kamal rollback` (previous release).
- `bin/kamal details` — container health/state.
- `bin/kamal app exec -i bin/rails dbconsole` — inspect the DB.
