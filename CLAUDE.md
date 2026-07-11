# CLAUDE.md

This file is a standing directive for **every** Claude Code session in this repository.
Read it fully before taking any action. It describes what the project is, how it works, and
the mandatory Git/PR workflow you must follow.

---

## 1. Project Overview

This project is a **shared Traefik v3.0 reverse proxy** designed to run on a single, already
provisioned cloud VM. It provides:

- **Dynamic routing** to multiple containerized applications running on the same host.
- **Automatic SSL certificates** via Let's Encrypt (ACME **TLS challenge**).
- **HTTP → HTTPS** redirection for all traffic.

The repository contains **only the proxy layer**. It assumes the VM already exists (with Docker
installed and DNS/firewall configured). Applications are deployed separately and register
themselves with Traefik through Docker labels on a shared network.

The project is intentionally minimal: there are **no Dockerfiles, no scripts, no IaC
(Terraform/CloudFormation), and no CI/CD** in the current repository. AWS CloudFormation, OCI
Terraform, and GitHub Actions deployment paths existed historically but were removed (commit
`bd7a150`). The only leftover artifact is the CloudFormation YAML custom tags in
`.vscode/settings.json`.

---

## 2. Architecture & How It Works

- **Traefik** runs as a single Docker Compose service (`traefik:v3.0`, `restart: always`).
- It uses the **Docker provider** with `exposedbydefault=false`, so containers must **opt in**
  with `traefik.enable=true`.
- Two entrypoints: `web` (`:80`) and `websecure` (`:443`). All `web` traffic is globally
  redirected to `websecure`.
- **SSL**: a Let's Encrypt resolver named `myresolver` uses the ACME TLS challenge. Certificates
  are stored in `traefik/data/acme.json` (mounted into the container at `/letscert/acme.json`).
  This file must have `600` permissions.
- The Traefik **dashboard** is enabled and served at `traefik.${DOMAIN}` over HTTPS
  (`api@internal`).
- Traefik discovers services by reading the **Docker socket** (`/var/run/docker.sock`, mounted
  read-only).
- Applications connect to Traefik through the external Docker network **`web-proxy`**.

---

## 3. Repository Structure

```
/
├── CLAUDE.md            # This file — directives for Claude Code sessions
├── README.md           # Human-facing deployment & usage guide
├── docker-compose.yml  # The Traefik service (entrypoints, ACME resolver, labels, network)
├── .env.example        # Required env vars: ACME_EMAIL, DOMAIN
├── .gitignore          # Excludes secrets/certs (.env*, acme.json, *.pem)
├── .vscode/
│   └── settings.json   # CloudFormation YAML tags (legacy artifact)
└── traefik/
    └── data/
        └── .gitkeep    # Placeholder; acme.json is created here at deploy time
```

All Traefik configuration is inlined as CLI flags and Docker labels in `docker-compose.yml` —
there are no separate static/dynamic Traefik config files.

---

## 4. Configuration

Configuration is provided via a `.env` file (copied from `.env.example`):

| Variable     | Purpose                                             |
| ------------ | --------------------------------------------------- |
| `DOMAIN`     | Base domain for routing (e.g. `example.com`).       |
| `ACME_EMAIL` | Email used for Let's Encrypt certificate issuance.  |

**Never commit secrets or certificates.** The following are gitignored and must stay untracked:

- `.env` and `.env.*` (except `.env.example`)
- `traefik/data/acme.json` (SSL certificate store)
- `*.pem` (SSH private keys)

---

## 5. Deploying / Adding Applications

The full step-by-step guide lives in **`README.md`** — refer to it for details. In summary:

**Deploying the proxy:** SSH into the VM, clone this repo, create and permission
`traefik/data/acme.json` (`touch` + `chmod 600`), copy `.env.example` → `.env` and set `DOMAIN`
and `ACME_EMAIL`, then run `docker compose up -d`.

**Adding a new app:** Each application lives in its own folder (e.g. `~/apps/<app>/`) with its
own `docker-compose.yml`. To expose it through Traefik, the app's containers must:

1. Set Traefik labels, e.g.:
   ```yaml
   labels:
     - "traefik.enable=true"
     - "traefik.http.routers.<name>.rule=Host(`sub.${DOMAIN}`)"
     - "traefik.http.routers.<name>.entrypoints=websecure"
     - "traefik.http.routers.<name>.tls.certresolver=myresolver"
     - "traefik.http.services.<name>.loadbalancer.server.port=<port>"
   ```
2. Join the shared network, declared as **external** on the app side:
   ```yaml
   networks:
     web-proxy:
       external: true
   ```

Traefik auto-detects the new containers and provisions certificates on demand.

---

## 6. Working Conventions & Environment Notes

- Use **Docker Compose v2** syntax: `docker compose` (not `docker-compose`).
- Target host OSes: Ubuntu (recommended), Amazon Linux 2023, or Oracle Linux, on AWS EC2 or
  Oracle Cloud (OCI). The VM is assumed to be **pre-provisioned** — this repo does not create it.
- There is currently **no CI/CD**. Do not assume automated tests, builds, or deploys run on push.
- Keep this repo focused on the proxy. Do not reintroduce IaC, scripts, or CI unless explicitly
  requested.

---

## 7. Git & PR Workflow — MANDATORY DIRECTIVES FOR CLAUDE

These rules are **non-negotiable** and apply to every session.

### 7.1 Never commit directly to `main`

- `main` is the primary branch and must **never** be committed to directly.
- For any change, **always create a new branch** and open a **Pull Request into `main`**.
- Use descriptive branch names, e.g. `feat/<short-description>`, `fix/<short-description>`, or
  `docs/<short-description>`.

### 7.2 Never perform Git actions autonomously — confirm every step with the user

Claude must **never** stage, commit, push, or open a PR on its own initiative. Each of the
following steps requires **explicit user confirmation before you perform it**:

1. **Staging** changes (`git add`) — ask first.
2. **Committing** (`git commit`) — ask first.
3. **Pushing** (`git push`) — ask first.
4. **Opening a Pull Request** — ask first.

Do not chain these steps together assuming prior approval. Approval for one step (e.g. staging)
is **not** approval for the next (e.g. committing). Confirm each one.

You may freely make and edit files in the working tree as part of a task, and you may run
read-only Git commands (`git status`, `git diff`, `git log`, `git branch`) to inspect state.
The confirmation requirement applies specifically to actions that stage, record, publish, or
propose changes.

### 7.3 Suggested conventions

- Write clear, imperative commit messages summarizing the change.
- Keep PRs focused and scoped to a single logical change.
- Reference the relevant context or issue in the PR description when applicable.
