# DevOps Lab

Phase 1 is a minimal FastAPI app with `/` and `/health` endpoints.

## Run locally with Docker

From the repository root, run:

```fish
docker build -t devops-lab:local ./app
docker run --rm --name devops-lab-app -p 127.0.0.1:8000:8000 devops-lab:local
```

In another terminal:

```fish
curl --fail-with-body http://127.0.0.1:8000/
curl --fail-with-body http://127.0.0.1:8000/health
```

Stop the container with Ctrl+C in the first terminal.

## Scan the image

```fish
trivy image --scanners vuln devops-lab:local
```

On 2026-09-27, Trivy 0.73.0 reported no Alpine OS vulnerabilities and three Python findings: two HIGH (`GHSA-6v7p-g79w-8964`, `CVE-2025-47273`) and one MEDIUM (`CVE-2026-59890`). The reported `msgpack` is vendored inside `pip`; standalone `msgpack` and `setuptools` were not importable in the running image. These findings are recorded rather than suppressed. Recheck them when the base image or vulnerability database changes.

## Phase 3: manual deployment to k3d

This records the earlier manual deployment. ArgoCD now tracks the live Deployment and Service; use the GitOps workflow below for changes. From the repository root:

```fish
kubectl config current-context
docker build -t devops-lab:local ./app
k3d image import devops-lab:local -c devops-lab
kubectl apply --context k3d-devops-lab -f k8s/app.yaml
kubectl rollout status --context k3d-devops-lab -n devops-lab deployment/devops-lab
kubectl get --context k3d-devops-lab -n devops-lab pods,services
kubectl port-forward --context k3d-devops-lab -n devops-lab service/devops-lab 8080:80
```

In another terminal:

```fish
curl --fail-with-body http://127.0.0.1:8080/
curl --fail-with-body http://127.0.0.1:8080/health
```

Stop port forwarding with Ctrl+C. The Service is private to the cluster; port forwarding provides temporary local access.

Validated on 2026-09-27: the Deployment rolled out, its pod was Ready `1/1`, the Service had a backing endpoint, and both HTTP paths returned `200 OK` through a port forward.

## Phase 4: Helm chart

The chart is in `helm/devops-lab`. To install it in a fresh `devops-lab` cluster, build and import the local image as shown above, then run:

```fish
helm lint helm/devops-lab
helm install devops-lab helm/devops-lab --namespace devops-lab --create-namespace --kube-context k3d-devops-lab --wait
```

This was the Phase 4 upgrade workflow before GitOps took over:

```fish
helm upgrade devops-lab helm/devops-lab --namespace devops-lab --kube-context k3d-devops-lab --wait
helm status devops-lab --namespace devops-lab --kube-context k3d-devops-lab
```

The Phase 3 Deployment and Service were adopted in place with Helm's `--take-ownership` option. During the first upgrade, Helm 4 required `--force-conflicts` once to take over the CPU request field previously managed by `kubectl`. The chart version is `0.1.1`, with a `50m` CPU request; Helm release revision 3 remains installed. Keep `k8s/app.yaml` as the Phase 3 reference.

## Phase 5: ArgoCD GitOps

The public Git source is `https://github.com/Vrivas99/devops-lab.git`. Install the pinned ArgoCD `v3.5.3` standard manifests into the local cluster:

```fish
kubectl create namespace argocd --context k3d-devops-lab
kubectl apply --context k3d-devops-lab -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.3/manifests/install.yaml
kubectl wait --context k3d-devops-lab -n argocd --for=condition=available deployment --all --timeout=180s
kubectl rollout status --context k3d-devops-lab -n argocd statefulset/argocd-application-controller
```

After pushing this repository to GitHub, create and sync the Application:

```fish
kubectl apply --context k3d-devops-lab -f argocd/application.yaml
kubectl config set-context k3d-devops-lab --namespace=argocd
argocd app sync devops-lab --core --kube-context k3d-devops-lab --app-namespace argocd
argocd app get devops-lab --core --kube-context k3d-devops-lab --app-namespace argocd
kubectl config set-context k3d-devops-lab --namespace=default
```

The ArgoCD CLI in `--core` mode needs `argocd` as the context namespace; the final command restores the default namespace. On 2026-09-27, the Application synchronized successfully and was Healthy, the pod was Ready `1/1`, and both HTTP paths returned `200 OK`. Synchronization remains manual in this phase. The older Helm release remains installed; avoid `helm upgrade` while ArgoCD manages these resources. Make live changes through Git and ArgoCD.

## Public read-only ArgoCD view

Tailscale Funnel provides a free public HTTPS address under `*.ts.net`. The tunnel runs inside the cluster, so the host needs no Tailscale installation, public IP, router port forwarding, or paid domain. This is for viewing ArgoCD Applications and their resources; ArgoCD shows workloads registered as Applications, not every arbitrary Kubernetes object. Currently, `devops-lab` is the only Application.

Current portal: **https://argocd-devops-lab.tail807fff.ts.net/**. Its address depends on the Tailscale tailnet and the persisted device identity; a fresh tailnet or deleted state volume may produce a different address.

The files `argocd/public-view.yaml` and `argocd/public-funnel.yaml` enable anonymous `role:readonly` access and deploy a small proxy plus a Tailscale container. Apply the view ConfigMaps with their **separate field manager** so the official ArgoCD ConfigMap fields are preserved:

```fish
kubectl apply --context k3d-devops-lab --server-side --field-manager=devops-lab-public-view -f argocd/public-view.yaml
kubectl apply --context k3d-devops-lab --server-side --field-manager=devops-lab-public-funnel -f argocd/public-funnel.yaml
kubectl rollout status --context k3d-devops-lab -n argocd deployment/argocd-funnel
kubectl logs --context k3d-devops-lab -n argocd deployment/argocd-funnel -c tailscale --tail=40
```

Open the login URL printed in the Tailscale logs and authorize the device in a free Personal tailnet. Then enable Funnel and read its public address:

```fish
kubectl exec --context k3d-devops-lab -n argocd deployment/argocd-funnel -c tailscale -- tailscale funnel --bg --yes http://127.0.0.1:8080
kubectl exec --context k3d-devops-lab -n argocd deployment/argocd-funnel -c tailscale -- tailscale funnel status
```

Funnel may print a second authorization URL the first time it is enabled. The Tailscale identity is stored in the local Kubernetes PersistentVolumeClaim `argocd-funnel-state`; no authentication key belongs in Git. The address stays the same across pod restarts while that claim and the Tailscale device remain. The host, Docker, and k3d cluster must be running for visitors to reach the portal.

Visitors can view applications without logging in; `admin` remains a separate authenticated account. To disable public exposure:

```fish
kubectl exec --context k3d-devops-lab -n argocd deployment/argocd-funnel -c tailscale -- tailscale funnel --https=443 off
```

On 2026-09-27, the public HTTPS endpoint returned HTTP 200, listed `devops-lab` and its Pod, Service, Deployment, and ReplicaSets, and reported `no` for an anonymous sync permission check. The portal was also opened successfully in Brave without login. Trivy 0.73.0 found no CRITICAL findings but reported seven HIGH entries in `tailscale/tailscale:v1.102.4` (four distinct CVEs across OpenSSL and Go packages) and one HIGH entry in `nginxinc/nginx-unprivileged:1.30.5-alpine` (`libexpat`). These findings remain open; rescan and update the images when fixes are published. Public DNS resolved via Cloudflare, Google, and Quad9 during validation, although the host's default DNS cache initially still returned no record.
