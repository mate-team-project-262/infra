# 🎬 MovieMatch (What2Watch) — Collaborative Movie Picker

[![Infrastructure CI](https://img.shields.io/github/actions/workflow/status/mate-team-project-262/infra/infra-ci.yml?branch=main&label=Infra%20CI&logo=githubactions)](./.github/workflows/infra-ci.yml)
[![Infrastructure CD](https://img.shields.io/github/actions/workflow/status/mate-team-project-262/infra/infra-cd.yml?branch=main&label=Production%20CD&logo=amazonaws)](./.github/workflows/infra-cd.yml)
[![Terraform](https://img.shields.io/badge/Terraform-1.6+-623CE4?logo=terraform&logoColor=white)](./terraform)
[![AWS](https://img.shields.io/badge/AWS-EC2%20%7C%20RDS%20%7C%20VPC-FF9900?logo=amazonaws&logoColor=white)](./docs/architecture_and_network.md)

**MovieMatch** is a real-time group decision web application that helps friends choose a movie together in under two minutes: create a shared room, join via a 6-character code, swipe through a curated TMDB movie deck, and let the interactive match roulette pick a winner.

---

## 🌐 Live Demo & Endpoints

* **Live Application:** [https://what2watch.duckdns.org](https://what2watch.duckdns.org)
* **OpenAPI / Swagger UI:** [https://what2watch.duckdns.org/swagger-ui/index.html](https://what2watch.duckdns.org/swagger-ui/index.html)
* **Edge Gateway Health:** [https://what2watch.duckdns.org/gateway-health](https://what2watch.duckdns.org/gateway-health)
* **Quick Demo Scenario:** Open the Live Application in two browser tabs $\rightarrow$ click **Create Room** in Tab 1 $\rightarrow$ copy the room code and click **Join Room** in Tab 2 $\rightarrow$ start the session, swipe on movies in both tabs, and view the matched results.
* *Note on Availability:* To optimize cloud costs, an automated FinOps schedule runs the AWS EC2 & RDS instances during active hours (**07:47 – 21:47 Kyiv Time / EET**) and pauses them overnight.

## 🧩 Multi-Repository Ecosystem

The platform is organized into specialized repositories sharing a unified delivery pipeline:

| Repository | Responsibility | Tech Stack |
| :--- | :--- | :--- |
| **`frontend`** | Single-Page Application (Room lobby, Swipe deck, Match roulette) | React 19, React Router 7, Vite 8, Nginx |
| **`backend`** | REST API, room state machine, voting engine, TMDB integration | Java 21, Spring Boot 3.5, Liquibase, MySQL 8.4, Testcontainers |
| **`infra`** *(this repo)* | AWS Terraform IaC, Docker Compose orchestration, SSL Gateway, Observability | Terraform, Docker Compose, Nginx, Prometheus, Grafana, Uptime Kuma |
| **`qa`** | End-to-end API & UI test automation suites | Playwright / REST Assured |

---

## 🚀 Run the Entire Stack Locally in 3 Steps

You can spin up the full platform locally (Nginx Gateway, React Frontend, Spring Boot Backend, and MySQL 8.0) directly from this repository—no external TMDB API key required (`TITLE_SOURCE=stub` is enabled by default):

```bash
git clone <INFRA_REPO_URL> && cd infra/compose
cp .env.example .env
docker compose up -d
```

* **Web App:** `http://localhost` | **Swagger UI:** `http://localhost/swagger-ui/index.html` | **Gateway Health:** `http://localhost/gateway-health`

---

## 🧭 Infrastructure Documentation (`docs/`)

| Guide | Key Topics Covered |
| :--- | :--- |
| [**Architecture & Network**](docs/architecture_and_network.md) | Browser-to-DB request flow, AWS VPC topology, `t3.micro` memory budgets, CORS & Nginx rate limiting. |
| [**CI/CD & Deployment**](docs/ci_cd_and_deployment.md) | `workflow_run` orchestration, immutable `sha-` image deployment, healthcheck polling, and 30s rollback runbook. |
| [**Monitoring, Backups & FinOps**](docs/monitoring_backups_and_finops.md) | Prometheus/Grafana/Uptime Kuma stack, alert rules, RDS MySQL backups, FinOps schedule, and SSH tunnels. |
| [**AI Agent Instructions**](AGENTS.md) | Validation commands (`terraform validate`, `docker compose config -q`, `shellcheck`) and security guardrails. |