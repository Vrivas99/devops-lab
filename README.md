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

This records the earlier manual deployment. The current Deployment and Service are managed by Helm; use the Helm workflow below for changes. From the repository root:

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

The current cluster already has this release. After editing the chart, run:

```fish
helm upgrade devops-lab helm/devops-lab --namespace devops-lab --kube-context k3d-devops-lab --wait
helm status devops-lab --namespace devops-lab --kube-context k3d-devops-lab
```

The Phase 3 Deployment and Service were adopted in place with Helm's `--take-ownership` option. During the first upgrade, Helm 4 required `--force-conflicts` once to take over the CPU request field previously managed by `kubectl`. The final chart version is `0.1.1`, with a `50m` CPU request; release revision 3 is deployed. Keep `k8s/app.yaml` as the Phase 3 reference and manage the live Deployment and Service through Helm.

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
argocd app sync devops-lab --core --kube-context k3d-devops-lab --app-namespace argocd
argocd app get devops-lab --core --kube-context k3d-devops-lab --app-namespace argocd
```

Synchronization is manual in this phase. The older Helm release history remains in the cluster; manage future changes through Git and ArgoCD.
