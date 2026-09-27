# DevOps Lab

Laboratorio local de Kubernetes con una aplicación FastAPI, despliegue gestionado por ArgoCD y un portal público de solo lectura. El código y la configuración están en [GitHub](https://github.com/Vrivas99/devops-lab); el clúster `devops-lab` corre en k3d sobre Docker.

## Cómo funciona

```text
GitHub (main) → ApplicationSet → ArgoCD → chart Helm → Deployment + Service → FastAPI
                                              ↑
                              imagen local importada en k3d

Navegador → Tailscale Funnel → proxy Nginx → portal ArgoCD (solo lectura)
```

ArgoCD lee `helm/devops-lab` desde la rama `main` y sincroniza la aplicación `devops-lab` en el namespace del mismo nombre. El chart crea una réplica de FastAPI y un Service interno. `/` devuelve `{"message":"DevOps lab"}` y `/health` devuelve `{"status":"ok"}`; Kubernetes usa `/health` para comprobar que el contenedor está listo y vivo.

La imagen actual es `devops-lab:local`. Hay que construirla e importarla en k3d: **un cambio de código en GitHub no genera ni distribuye una imagen nueva todavía**. Los cambios al chart sí se sincronizan automáticamente. La sincronización tiene `selfHeal: true` y `prune: false`: ArgoCD recupera recursos modificados o borrados en el clúster, pero retirar un recurso del chart requiere una eliminación manual. Si se borra la Application en cascada, el ApplicationSet la vuelve a crear y ArgoCD restaura sus recursos. El ApplicationSet se instala inicialmente con `kubectl` y se debe reaplicar si se borra.

## Estructura del repositorio

| Ruta | Función |
| --- | --- |
| `app/` | API FastAPI, dependencias y Dockerfile basado en `python:3.13-alpine`. |
| `helm/devops-lab/` | Chart que define el Deployment, Service, imagen, réplica y recursos. Es la fuente del despliegue actual. |
| `argocd/applicationset.yaml` | Registra el chart de GitHub en ArgoCD y mantiene presente la Application. |
| `argocd/public-view.yaml` | Habilita acceso anónimo con permisos `role:readonly` al portal. |
| `argocd/public-funnel.yaml` | Despliega el proxy, Tailscale Funnel y el volumen que conserva la identidad del dispositivo. |
| `k8s/app.yaml` | Manifiestos del despliegue manual anterior; solo referencia. No aplicarlos sobre el despliegue gestionado por ArgoCD. |
| `SKILL.md` | Contexto y reglas de trabajo para futuras sesiones de Codex. |

## Herramientas y requisitos

El entorno actual usa CachyOS/Arch Linux y fish. Para reproducirlo localmente se necesitan Git, Docker, k3d, kubectl, Helm y Trivy. El repositorio público de GitHub es la fuente Git de ArgoCD; se necesita conexión a Internet para descargar sus manifiestos y acceder al repositorio. Tailscale Funnel requiere una cuenta gratuita y una autorización inicial en el navegador. ArgoCD CLI y GitHub CLI están instalados en el equipo, pero los comandos de esta guía funcionan con `kubectl` y Git.

GitHub Actions, GHCR, Prometheus, Grafana y Loki están previstos, pero aún no están configurados. La versión actual utiliza una imagen local; no hay pipeline de CI ni registro de imágenes.

Para obtener el proyecto en otro equipo:

```fish
git clone https://github.com/Vrivas99/devops-lab.git
cd devops-lab
```

## Ejecutar y escanear la aplicación en Docker

Desde la raíz del repositorio:

```fish
docker build -t devops-lab:local ./app
docker run --rm --name devops-lab-app -p 127.0.0.1:8000:8000 devops-lab:local
```

En otra terminal:

```fish
curl --fail-with-body http://127.0.0.1:8000/
curl --fail-with-body http://127.0.0.1:8000/health
trivy image --scanners vuln devops-lab:local
```

Detén el contenedor con `Ctrl+C`. Trivy es la herramienta de análisis de vulnerabilidades. En la última revisión documentada (2026-09-27), la imagen de la aplicación no tuvo hallazgos del sistema Alpine y registró dos HIGH y uno MEDIUM en paquetes Python; los hallazgos siguen abiertos y se deben revisar al actualizar la imagen o la base de datos de Trivy. Las imágenes de Tailscale y Nginx del túnel también tuvieron hallazgos HIGH pendientes de revisión.

## Levantar el laboratorio en k3d

El clúster existente se llama `devops-lab` y su contexto es `k3d-devops-lab`. Para reproducirlo desde cero, ejecuta estos comandos desde la raíz del repositorio. Si el clúster ya existe, comienza en `docker build` y omite la creación de namespaces e instalación de ArgoCD cuando ya estén presentes.

```fish
k3d cluster create devops-lab
kubectl config current-context
kubectl create namespace devops-lab --context k3d-devops-lab
docker build -t devops-lab:local ./app
k3d image import devops-lab:local -c devops-lab
kubectl create namespace argocd --context k3d-devops-lab
kubectl apply --context k3d-devops-lab -n argocd --server-side --force-conflicts -f https://raw.githubusercontent.com/argoproj/argo-cd/v3.5.3/manifests/install.yaml
kubectl wait --context k3d-devops-lab -n argocd --for=condition=available deployment --all --timeout=180s
kubectl rollout status --context k3d-devops-lab -n argocd statefulset/argocd-application-controller
kubectl apply --context k3d-devops-lab -f argocd/applicationset.yaml
```

El ApplicationSet apunta al repositorio público `Vrivas99/devops-lab`, rama `main`. Publica los cambios allí antes de esperar que ArgoCD los despliegue. No uses `kubectl apply -f k8s/app.yaml` ni `helm upgrade` para cambiar los recursos actuales: ArgoCD los gestiona desde Git. En el clúster existente queda una release de Helm previa, pero no es el controlador activo.

Comprueba el estado:

```fish
helm lint helm/devops-lab
kubectl get --context k3d-devops-lab -n argocd applicationsets,applications
kubectl get --context k3d-devops-lab -n devops-lab deployment,service,pods
kubectl rollout status --context k3d-devops-lab -n devops-lab deployment/devops-lab
```

Para probar el Service desde el equipo, ejecuta el port-forward en una terminal:

```fish
kubectl port-forward --context k3d-devops-lab -n devops-lab service/devops-lab 8080:80
```

Y en otra:

```fish
curl --fail-with-body http://127.0.0.1:8080/
curl --fail-with-body http://127.0.0.1:8080/health
```

Detén el port-forward con `Ctrl+C`. El Service solo tiene acceso interno en Kubernetes.

## Portal público de ArgoCD

La instancia actual está en **https://argocd-devops-lab.tail807fff.ts.net/**. Cualquier visitante puede ver las Applications registradas en ArgoCD y sus recursos sin iniciar sesión; las acciones de administración requieren autenticación. Actualmente solo está registrada `devops-lab`. El portal estará disponible mientras funcionen el equipo, Docker, el clúster y el túnel. La dirección depende de la cuenta Tailscale y de la identidad guardada en el volumen; un entorno nuevo puede obtener otra URL.

En un clúster nuevo, configura la vista y el túnel después de instalar ArgoCD. Mantén el `field-manager` indicado para conservar los demás campos de los ConfigMaps de ArgoCD:

```fish
kubectl apply --context k3d-devops-lab --server-side --field-manager=devops-lab-public-view -f argocd/public-view.yaml
kubectl apply --context k3d-devops-lab --server-side --field-manager=devops-lab-public-funnel -f argocd/public-funnel.yaml
kubectl rollout status --context k3d-devops-lab -n argocd deployment/argocd-funnel
kubectl logs --context k3d-devops-lab -n argocd deployment/argocd-funnel -c tailscale --tail=40
```

Abre la URL de inicio de sesión que aparece en los logs y autoriza el dispositivo en Tailscale. Luego habilita Funnel; la primera vez puede aparecer otra URL para autorizarlo:

```fish
kubectl exec --context k3d-devops-lab -n argocd deployment/argocd-funnel -c tailscale -- tailscale funnel --bg --yes http://127.0.0.1:8080
kubectl exec --context k3d-devops-lab -n argocd deployment/argocd-funnel -c tailscale -- tailscale funnel status
```

No guardes claves ni contraseñas en Git. La identidad Tailscale permanece en el PVC `argocd-funnel-state`. Para desactivar la publicación:

```fish
kubectl exec --context k3d-devops-lab -n argocd deployment/argocd-funnel -c tailscale -- tailscale funnel --https=443 off
```
