# 🏗️ Team 262 — Cloud Infrastructure & DevOps Architecture

This repository contains Infrastructure as Code (IaC), container configurations, deployment scripts, and architecture documentation for the **Team 262** project.

---

## 📐 End-to-End System & CI/CD Architecture

```mermaid
graph TB
    subgraph GitHub ["1. Source Control (GitHub Organization)"]
        FE_Repo["frontend repo (JS / npm)"]
        BE_Repo["backend repo (Java 21 / Maven)"]
        AN_Repo["analytics repo (Python / Pandas)"]
        IN_Repo["infra repo (Terraform / Compose)"]
    end

    subgraph CICD ["2. CI/CD Automation (GitHub Actions)"]
        CI["CI Pipeline: Test & Build"]
        GHCR[("GHCR: Container Registry")]
        CD["CD Pipeline: SSH Deploy"]
    end

    subgraph AWS ["3. Cloud Environment (AWS EC2 Free Tier — Ubuntu 24.04)"]
        Nginx["Nginx Reverse Proxy (:80 / :443 SSL)"]
        
        subgraph DockerNet ["Isolated Docker Bridge Network"]
            FE_Cont["Frontend Static Assets"]
            BE_Cont["Spring Boot API (:8080)"]
            DB_Cont[("MySQL 8.0 (:3306)\nPersistent Volume")]
        end
    end

    Users(("End Users"))

    %% Flows
    FE_Repo -->|PR / Merge to main| CI
    BE_Repo -->|PR / Merge to main| CI
    CI -->|Push Docker Images| GHCR
    GHCR -->|Trigger| CD
    IN_Repo -.->|Provision & Config| AWS
    CD ==>|docker compose pull & up -d| AWS

    Users ==>|HTTPS :443| Nginx
    Nginx -->|/*| FE_Cont
    Nginx -->|/api/*| BE_Cont
    BE_Cont -->|JDBC :3306| DB_Cont
```

---

## 📁 Repository Structure

* **`terraform/`** — Terraform plans for provisioning cloud resources (AWS EC2, Security Groups, VPC).
* **`compose/`** — Production Docker Compose files and Nginx reverse-proxy configurations.
* **`manifests/`** — Kubernetes deployment and service manifests for portfolio and cloud-native scaling.
* **`scripts/`** — Automation scripts for database backups and server maintenance.

---

## 🔐 Security by Default Principles

1. **Zero Hardcoded Secrets:** Database passwords, API tokens, and SSH keys are never stored in Git. Local environments use `.env` (via `.env.example` templates), while CI/CD pipelines inject secrets via **GitHub Actions Secrets** (`${{ secrets.* }}`) and AWS Parameter Store.
2. **Branch Protection & Git Flow:** Direct pushes to `main` and `develop` are blocked across all repositories. All changes require a Pull Request and Squash Merge.
3. **Network Isolation:** In production, the MySQL 8.0 database runs inside an isolated Docker bridge network without public port exposure (`3306` is accessible only to the `backend` service).

---

## 💾 Backup & Disaster Recovery Plan

* **RPO (Recovery Point Objective):** `< 24 hours` — automated daily logical backups of the MySQL database via `mysqldump` cron job with 7-day retention.
* **RTO (Recovery Time Objective):** `< 15 minutes` — full infrastructure and application recovery via Terraform state and Docker Compose deployment from GitHub Container Registry.