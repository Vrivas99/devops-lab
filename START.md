# Encender el laboratorio después de reiniciar el PC

Ejecuta estos comandos en fish. El clúster `devops-lab` ya existe: hay que iniciarlo, no crearlo de nuevo. Docker está configurado para permanecer apagado al arrancar el equipo; `sudo` pedirá tu contraseña local.

```fish
sudo systemctl start docker.service
k3d cluster start devops-lab
kubectl wait --context k3d-devops-lab --for=condition=Ready node --all --timeout=180s
kubectl rollout status --context k3d-devops-lab -n argocd deployment/argocd-server --timeout=180s
kubectl rollout status --context k3d-devops-lab -n argocd deployment/argocd-funnel --timeout=180s
kubectl rollout status --context k3d-devops-lab -n devops-lab deployment/devops-lab --timeout=180s
```

Comprueba ArgoCD, la aplicación y el túnel:

```fish
kubectl get --context k3d-devops-lab -n argocd application/devops-lab
kubectl get --context k3d-devops-lab -n devops-lab deployment,service,pods
kubectl exec --context k3d-devops-lab -n argocd deployment/argocd-funnel -c tailscale -- tailscale funnel status
curl --fail-with-body --silent --show-error --output /dev/null --write-out '%{http_code}\n' https://argocd-devops-lab.tail807fff.ts.net/
```

La Application debe aparecer `Synced/Healthy`, los pods `Running` y el portal debe responder `200`. Puede tardar unos instantes más en estar disponible por Internet después de que los pods estén listos. El túnel debería reanudarse con su configuración persistente; no hace falta repetir el inicio de sesión de Tailscale mientras se conserve el volumen `argocd-funnel-state` y el dispositivo siga autorizado.

Portal: https://argocd-devops-lab.tail807fff.ts.net/ · La [guía general](README.md) explica cómo funciona el proyecto y cómo reproducirlo desde cero.
