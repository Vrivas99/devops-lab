---
name: devops-lab
description: Guide incremental work in this local, free-tool DevOps lab; use for changes to the app, containers, Kubernetes, GitOps, CI, security scanning, or observability in this repository.
---

# DevOps Lab

## Purpose and architecture

Build a small, reproducible DevOps platform around a minimal FastAPI application, using local infrastructure and free GitHub features where possible. The planned path is: source code and GitHub Actions CI → Docker image and Trivy scan → GHCR → Helm deployment on the local k3d Kubernetes cluster → ArgoCD reconciliation. Prometheus, Grafana, and Loki will provide metrics, dashboards, and logs in a later phase. This is a plan, not a claim that these pieces already exist.

## Tools and local environment

- Host: CachyOS / Arch Linux; interactive shell: fish. Give user-facing commands in fish-compatible syntax.
- Reported installed: Docker, k3d, kubectl, Helm, ArgoCD CLI, Trivy, GitHub CLI, and Codex CLI. Planned project tools also include Git, Kubernetes, GitHub Actions, GHCR, Prometheus, Grafana, Loki, and FastAPI.
- Existing cluster: `devops-lab`, context `k3d-devops-lab`. On 2026-09-27, `kubectl get nodes -o wide` showed `k3d-devops-lab-server-0` Ready, running `v1.35.5+k3s1`.

## Working rules

- Work one small, agreed stage at a time. Inspect existing files and state, explain the intended change, modify, validate with real commands, then report results. Do not start the next phase automatically.
- Keep implementations simple, minimal, production-inspired, and reproducible from this repository. Add only components needed for the current stage; avoid large multi-file changes unless requested.
- Inspect files before replacing or deleting them. Explain major architectural tradeoffs and let the user choose before implementation.
- Never commit secrets. Prefer local execution and free GitHub features; avoid cloud costs.
- Do not claim success from a command that was not run or whose output was not checked.

## Repository conventions

- Intended layout: `app/` for FastAPI and its Dockerfile, `k8s/` for manual manifests, `helm/` for the chart, `argocd/` for GitOps definitions, `monitoring/` for observability configuration, `scripts/` for useful reproducible helpers, `.github/workflows/` for CI, and `README.md` for setup and operation.
- Create directories and files only as their phase needs them. Keep configuration in versioned files and document required local or GitHub settings without storing credentials.
- Use clear names and small, reviewable changes. Update the Current Status and Next Step sections when completing a stage.

## Validation and recommended commands

- After each stage, run the checks relevant to that stage and record the command, observed result, and any limitation. For the app, validate both `/` and `/health` with `curl`; for images, build/run locally and scan with Trivy; for Kubernetes, check rollout, service access, and cluster state; for Helm and GitOps, verify the actual installed or synced state.
- Safe inspection commands: `ls -la`, `git status --short` (once Git is initialized), `docker info`, `k3d cluster list`, `kubectl config current-context`, and `kubectl get nodes`.
- Before a cluster operation, confirm the context is `k3d-devops-lab`. Do not assume a command succeeded from its exit code alone when it has a checkable outcome.

## Project phases

1. Minimal FastAPI app with `/` and `/health`, `requirements.txt`, Dockerfile, local build/run, and `curl` validation.
2. Trivy image scan, vulnerability review, and image adjustments if warranted.
3. Minimal Deployment and Service; deploy and validate manually in k3d.
4. Convert manifests to a Helm chart; validate install and upgrade.
5. Install ArgoCD, add an Application, and reconcile deployment from Git.
6. Expand the GitHub repository with Actions CI for tests, build, Trivy, and GHCR push.
7. Have CI update the GitOps image version and verify ArgoCD deploys it.
8. Add Prometheus, Grafana, Loki, basic metrics, dashboards, and log visibility.

Potential later extensions include ephemeral PR environments, cert-manager, External Secrets or Vault, Kyverno, OpenTelemetry, Backstage, and Crossplane. None is part of the current scope.

## Do not assume

- A Git repository, remote, GitHub credentials, GHCR package, image, application, Helm chart, ArgoCD installation, or monitoring stack exists until verified.
- The reported local tools, Docker daemon, or cluster will remain available; check before relying on them.
- Network access, registry permissions, secret values, or an acceptable vulnerability threshold. Verify or ask when a decision depends on them.

## Decisions already made

- Use the stated stack and the existing local k3d cluster; favor free, local execution.
- Use Trivy for image security, ArgoCD for GitOps, GitHub Actions for CI, GHCR for images, and Prometheus/Grafana/Loki for eventual observability.
- The user chose `python:3.13-alpine` for the app image in Phase 2 after a comparison with Debian slim.
- The Phase 3 Deployment and Service in namespace `devops-lab` were adopted by a Helm 4 release named `devops-lab`. The namespace itself remains outside the release.
- The user chose public `Vrivas99/devops-lab` as the Git source. ArgoCD tracks the Helm chart at `helm/devops-lab` on `main`; sync is manual until Phase 7. The older Helm release remains installed; avoid Helm upgrades and use Git and ArgoCD for further live changes.
- For free public viewing, expose ArgoCD through Tailscale Funnel in the cluster with a `*.ts.net` HTTPS address. Visitors receive anonymous `role:readonly` permissions. The Tailscale device state lives in a local PVC, never in Git. Apply `argocd/public-view.yaml` with the distinct field manager documented in `README.md` to preserve the upstream ArgoCD ConfigMaps.
- Finish and validate each phase before proceeding. Phase 1 was approved after this `SKILL.md` was reviewed.

## Current Status

- Phases 1–5 are complete. The app image uses Alpine; the Phase 2 Trivy scan reported 0 Alpine OS findings and 3 Python findings (2 HIGH, 1 MEDIUM). See `README.md` for the remaining findings.
- Git is initialized on `main` with public remote `https://github.com/Vrivas99/devops-lab.git`. ArgoCD `v3.5.3` is installed in namespace `argocd`. On 2026-09-27, Application `devops-lab` synchronized the chart from GitHub and was Healthy; the pod was Ready `1/1`, and `/` and `/health` returned HTTP 200 through the Service. Helm release `devops-lab` remains installed at chart `0.1.1`, revision 3. CI and GHCR are not configured yet.
- The active kubectl context was `k3d-devops-lab`, and its single server node was Ready when checked on 2026-09-27.
- Public ArgoCD portal: `https://argocd-devops-lab.tail807fff.ts.net/` via Tailscale Funnel. On 2026-09-27, the HTTPS endpoint returned 200, exposed `devops-lab` to an anonymous viewer, and denied anonymous sync. The host's default DNS cache may take time to update. Trivy reported seven HIGH entries for the Tailscale image and one HIGH entry for the NGINX image; see `README.md`.

## Next Step

When the user requests the next stage, run Phase 6: add GitHub Actions CI for app checks, image build, Trivy scan, and GHCR push. Review the three documented Python findings before choosing a CI vulnerability gate.
