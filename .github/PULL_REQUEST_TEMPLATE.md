## What and why
<!-- Briefly describe the infrastructure or configuration changes and link the Jira task: T2-XX -->

## How to check
1. 

## Checklist
- [ ] `Infrastructure CI (Validate & Lint)` passes (Terraform validate, Compose syntax, ShellCheck)
- [ ] The branch follows Git Flow naming (`feat/T2-XX-...` or `fix/T2-XX-...`) and targets `develop`
- [ ] `.env.example` is updated if new environment variables were introduced
- [ ] No hardcoded secrets, private keys, or real `.env` files in the commit