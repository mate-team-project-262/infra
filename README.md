# 🎬 W2W — What to Watch

<!-- =========================================================================
     SECTION 1: UNIFIED PROJECT OVERVIEW (KEEP IDENTICAL ACROSS ALL 4 REPOS)
     ========================================================================= -->

[![Infra CI](https://img.shields.io/github/actions/workflow/status/mate-team-project-262/infra/infra-ci.yml?branch=main&label=Infra%20CI&logo=githubactions)](https://github.com/mate-team-project-262/infra/actions/workflows/infra-ci.yml)
[![Infra CD](https://img.shields.io/github/actions/workflow/status/mate-team-project-262/infra/infra-cd.yml?branch=main&label=Infra%20CD&logo=amazonaws)](https://github.com/mate-team-project-262/infra/actions/workflows/infra-cd.yml)
[![Backend CI](https://img.shields.io/github/actions/workflow/status/mate-team-project-262/backend/ci.yml?branch=main&label=Backend%20CI&logo=githubactions)](https://github.com/mate-team-project-262/backend/actions)
[![Frontend CI](https://img.shields.io/github/actions/workflow/status/mate-team-project-262/frontend/ci.yml?branch=main&label=Frontend%20CI&logo=githubactions)](https://github.com/mate-team-project-262/frontend/actions)

**Stop arguing about what to watch.** W2W (What to Watch) is a real-time collaborative movie picker: create a room, invite friends via link, 6-character code, or QR code, swipe through the same 20 curated TMDB movies, and let the interactive match roulette pick the film your whole group agrees on — no account required.

## 🌐 Live Demo & Endpoints

* **Live Application:** [https://what2watch.duckdns.org](https://what2watch.duckdns.org)
* **OpenAPI / Swagger UI:** [https://what2watch.duckdns.org/swagger-ui/index.html](https://what2watch.duckdns.org/swagger-ui/index.html)
* **Edge Gateway Health:** [https://what2watch.duckdns.org/gateway-health](https://what2watch.duckdns.org/gateway-health)

> **Availability note:** To optimize AWS Free Tier costs, an automated FinOps schedule pauses the cloud servers overnight (**22:00–08:00 EET, Kyiv time**). If the live demo is sleeping, see the screenshots below.

![W2W Landing Page](https://raw.githubusercontent.com/mate-team-project-262/frontend/main/docs/screenshots/landing.jpg)

| Swipe Session | Match Results |
| :---: | :---: |
| ![W2W Swipe Session](https://raw.githubusercontent.com/mate-team-project-262/frontend/main/docs/screenshots/swipe.jpg) | ![W2W Match Results](https://raw.githubusercontent.com/mate-team-project-262/frontend/main/docs/screenshots/results.jpg) |

### Try it in 60 seconds
1. Open the Live Application and click **Create a room**, then choose content type, genres, and duration.
2. Open the invite link in a second browser or incognito window and join under another name.
3. The host clicks **Start session**; everyone swipes through the same 20 movies (like or skip).
4. When everyone finishes, view the matched winner — or spin the fair roulette to break a tie.

## 🧩 Repository Ecosystem

The platform is organized into four repositories connected by a unified GitHub Actions + GHCR + AWS EC2 delivery pipeline:

```text
Browser (HTTPS) ─▶ Nginx Gateway (TLS, CSP/HSTS, Rate Limiting)
                     ├─ /       ─▶ React SPA (frontend)
                     └─ /api/*  ─▶ Spring Boot API (backend) ─▶ AWS RDS MySQL + TMDB / Gmail SMTP
```

| Repository | Responsibility | Core Tech Stack |
| :--- | :--- | :--- |
| **[`frontend`](https://github.com/mate-team-project-262/frontend)** | SPA UI: room lobby, swipe deck, profiles, match roulette | React 19, TypeScript, TanStack Query, Vite 8, Nginx |
| **[`backend`](https://github.com/mate-team-project-262/backend)** | REST API, room state machine, voting engine, TMDB & SMTP | Java 21, Spring Boot 3.5, Liquibase, MySQL 8.0, Testcontainers |
| **[`infra`](https://github.com/mate-team-project-262/infra)** *(this repo)* | AWS Terraform IaC, Docker Compose, SSL Gateway, Observability | Terraform, AWS (EC2/RDS/VPC/S3), Nginx, Prometheus, Grafana |
| **[`analytics`](https://github.com/mate-team-project-262/analytics)** | Data cleaning, EDA, survey & product metrics visualization | Python 3, Jupyter Notebook, Pandas, NumPy, Matplotlib, Seaborn |

## 🚀 Run the Entire Stack Locally (3 Steps)

Spin up the full platform locally (Nginx Gateway, React Frontend, Spring Boot Backend, and MySQL 8.0) via the `infra` repository — no external TMDB API key required (`TITLE_SOURCE=stub` is enabled by default):

```bash
git clone https://github.com/mate-team-project-262/infra.git && cd infra/compose
cp .env.example .env
docker compose up -d
```

* **Local App:** `http://localhost` · **Swagger UI:** `http://localhost/swagger-ui/index.html` · **Gateway Health:** `http://localhost/gateway-health`

---

<!-- =========================================================================
     SECTION 2: INFRASTRUCTURE REPOSITORY DETAILS
     ========================================================================= -->

## 🏗️ About This Repository (`infra`)

[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?logo=terraform&logoColor=white)](./terraform)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20RDS%20%7C%20VPC%20%7C%20S3-FF9900?logo=amazonaws&logoColor=white)](./docs/architecture_and_network.md)
[![Docker Compose](https://img.shields.io/badge/Docker%20Compose-Production-2496ED?logo=docker&logoColor=white)](./compose)

This repository owns the AWS cloud infrastructure, production Docker Compose orchestration, Nginx edge security, automated database backups, and observability stack for W2W.

### Repository Layout

| Path | Description |
| :--- | :--- |
| `terraform/` | AWS IaC (`eu-central-1`): custom VPC, public/private subnets, Security Groups, App & Monitoring EC2, Private RDS MySQL 8.0. |
| `compose/` | Production & local `docker-compose.yml`, Nginx reverse proxy config (TLS 1.2/1.3, rate limiting, security headers), `.env.example`. |
| `monitoring/` | Prometheus scrape configs (Node Exporter & Spring Boot Actuator over private VPC), Grafana dashboards, Telegram alerting. |
| `scripts/` | Automated MySQL-to-S3 backup scripts (`backup_mysql.sh`) and operational utilities. |
| `.github/workflows/` | Infrastructure CI validation, production CD deployment, and FinOps EC2/RDS power schedule. |

### Infrastructure Documentation (`docs/`)

| Guide | Key Topics Covered |
| :--- | :--- |
| [**Architecture & Network**](docs/architecture_and_network.md) | Browser-to-DB request flow, AWS VPC topology, `t3.micro` memory budgets, CORS & tiered Nginx rate limiting. |
| [**CI/CD & Deployment**](docs/ci_cd_and_deployment.md) | Immutable `sha-*` image delivery, healthcheck polling, bottom-up deploy order, and fast rollback runbook. |
| [**Monitoring, Backups & FinOps**](docs/monitoring_backups_and_finops.md) | Prometheus, Grafana, Uptime Kuma, Telegram alerts, RDS S3 backups, FinOps schedule, and SSH tunnels. |
| [**AI Agent Instructions**](AGENTS.md) | Validation commands (`terraform validate`, `docker compose config -q`, `shellcheck`) and security guardrails. |