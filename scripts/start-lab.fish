#!/usr/bin/env fish

set -l context k3d-devops-lab
set -l portal https://argocd-devops-lab.tail807fff.ts.net/

echo 'Iniciando Docker...'
sudo systemctl start docker.service
or exit 1

echo 'Iniciando el clúster devops-lab...'
k3d cluster start devops-lab
or exit 1

echo 'Esperando a Kubernetes y los despliegues...'
kubectl --context $context wait node --all --for=condition=Ready --timeout=180s
or exit 1
kubectl --context $context -n argocd rollout status deployment/argocd-server --timeout=180s
or exit 1
kubectl --context $context -n argocd rollout status statefulset/argocd-application-controller --timeout=180s
or exit 1
kubectl --context $context -n argocd rollout status deployment/argocd-funnel --timeout=180s
or exit 1
kubectl --context $context -n devops-lab rollout status deployment/devops-lab --timeout=180s
or exit 1

echo 'Comprobando ArgoCD y el túnel...'
kubectl --context $context -n argocd wait application/devops-lab --for=jsonpath='{.status.health.status}'=Healthy --timeout=180s
or exit 1
kubectl --context $context -n argocd wait application/devops-lab --for=jsonpath='{.status.sync.status}'=Synced --timeout=180s
or exit 1
kubectl --context $context -n argocd get application/devops-lab
or exit 1
kubectl --context $context -n argocd exec deployment/argocd-funnel -c tailscale -- tailscale funnel status
or exit 1

curl --retry 12 --retry-delay 5 --retry-all-errors --connect-timeout 5 --max-time 10 --location --fail --silent --show-error --output /dev/null --write-out 'Portal ArgoCD: HTTP %{http_code}\n' $portal
or exit 1

echo 'Lab listo.'
