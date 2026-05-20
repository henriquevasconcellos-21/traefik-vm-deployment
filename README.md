# Infrastructure & Deployment Guide

This project manages a shared Traefik reverse proxy on an EC2 instance, enabling dynamic routing and automatic SSL (Let's Encrypt) for multiple containerized applications.

## 1. Deploying to an Existing EC2

### Prerequisites
- **EC2 Instance:** Running Ubuntu (recommended) or Amazon Linux 2.
- **Docker & Docker Compose:** Installed on the instance.
- **Security Group:** Ports `80` (HTTP), `443` (HTTPS), and `22` (SSH) must be open to your IP or globally.
- **DNS Records:** Point your domain and subdomains (e.g., `traefik.example.com`, `api.example.com`, `app.example.com`) to the EC2 Elastic IP.

### Recommended Directory Structure
We recommend keeping your infrastructure and applications organized as follows:
```text
/home/ubuntu/
├── traefik-vm-deployment/  # This repository (Shared Proxy)
└── apps/                    # All your applications
    ├── app-1/               # NestJS + Vuejs project
    │   └── docker-compose.yml
    └── app-2/
        └── docker-compose.yml
```

### Step-by-Step Deployment

1. **Connect to your EC2:**
   ```bash
   ssh -i your-key.pem ubuntu@your-ec2-ip
   ```

2. **Clone the infrastructure repository:**
   ```bash
   git clone https://github.com/your-repo/traefik-vm-deployment.git
   cd traefik-vm-deployment
   ```

3. **Prepare the environment:**
   ```bash
   # Create the SSL certificate storage file with strict permissions
   touch traefik/data/acme.json
   chmod 600 traefik/data/acme.json

   # Configure environment variables
   cp .env.example .env
   nano .env
   ```
   *Inside the editor: Update `DOMAIN` and `ACME_EMAIL`. Press `Ctrl+O` followed by `Enter` to save, and `Ctrl+X` to exit.*

4. **Launch Traefik:**
   ```bash
   docker compose up -d
   ```

5. **Create the applications directory:**
   ```bash
   mkdir -p ~/apps
   ```

---

## 2. Adding New Applications

To add a new application (like your NestJS/Vue.js stack), create a dedicated folder inside `~/apps`.

### Example: NestJS + Vue.js Setup

1. **Create the app directory:**
   ```bash
   mkdir -p ~/apps/my-new-app
   cd ~/apps/my-new-app
   ```

2. **Create a `docker-compose.yml`:**

```yaml
version: '3.8'

services:
  backend:
    image: my-nestjs-api:latest
    container_name: nestjs-api
    networks:
      - web-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.api.rule=Host(`api.${DOMAIN}`)"
      - "traefik.http.routers.api.entrypoints=websecure"
      - "traefik.http.routers.api.tls.certresolver=myresolver"
      - "traefik.http.services.api.loadbalancer.server.port=3000"

  frontend:
    image: my-vue-app:latest
    container_name: vue-frontend
    networks:
      - web-proxy
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.frontend.rule=Host(`app.${DOMAIN}`)"
      - "traefik.http.routers.frontend.entrypoints=websecure"
      - "traefik.http.routers.frontend.tls.certresolver=myresolver"
      - "traefik.http.services.frontend.loadbalancer.server.port=80"

networks:
  web-proxy:
    external: true
```

### Deployment Steps

1. **Dockerize your apps:** Ensure you have Dockerfiles for both NestJS and Vue.js.
2. **Deploy:** From inside `~/apps/my-new-app`, run:
   ```bash
   docker compose up -d
   ```
   Traefik will automatically detect the new containers via the `web-proxy` network and provision SSL certificates.

## Troubleshooting

- **Check Traefik Logs:** `docker compose logs -f traefik` (run from the infrastructure folder)
- **Certificate Issues:** Ensure `acme.json` has `600` permissions.
- **Network Check:** Ensure your app's `docker-compose.yml` specifies `external: true` for the `web-proxy` network.
