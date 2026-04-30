# DevSecOps Tier 4 – AKS + Helm + Cloudflare
## DATE: 28 April 2026
This repo builds and deploys the `aks-demo` app to Azure Kubernetes Service (AKS) using:

- Azure Bicep for infra (AKS + ACR)
- Docker for image build
- Helm for Kubernetes manifests
- NGINX Ingress Controller
- Cloudflare Tunnel for external HTTPS access

## DESIGN

                      FINAL AKS ARCHITECTURE DIAGRAM
```plaintext
                    ┌─────────────────────────────────┐
                    │        Cloudflare DNS           │
                    │  staging.systematicdefence.tech │
                    └──────────────┬──────────────────┘
                                   │
                                   ▼
                        ┌────────────────────────┐
                        │  Cloudflare Tunnel     │
                        │  (cloudflared pod)     │
                        │   namespace: cloudflare│
                        └────────────┬───────────┘
                                     │
                                     ▼
                        ┌───────────────────────────┐
                        │   NGINX Ingress Ctrl      │
                        │   namespace: ingress-nginx│
                        └────────────┬──────────────┘
                                     │
                                     ▼
                        ┌──────────────────────────────────────┐
                        │     Ingress Rule                     │
                        │  host: staging.systematicdefence.tech│
                        └────────────┬─────────────────────────┘
                                     │
                                     ▼
                        ┌─────────────────────────┐
                        │   aks-demo-service      │
                        │   namespace: staging    │
                        └────────────┬────────────┘
                                     │
                                     ▼
                        ┌────────────────────────┐
                        │   aks-demo pods        │
                        │   namespace: staging   │
                        └────────────────────────┘
```
## Folder structure

- `infra/` – Bicep templates for AKS + ACR + RG
- `helm/aks-demo/` – Helm chart for the app, ingress, and cloudflared
- `.github/workflows/aks_cicd.yaml` – CI/CD pipeline

## Helm chart

The chart lives in `helm/aks-demo` and includes:

- `deployment.yaml` – `aks-demo` Deployment
- `service.yaml` – ClusterIP Service
- `ingress.yaml` – NGINX Ingress
- `cloudflared-deployment.yaml` – Cloudflare Tunnel Deployment

Values:

- `values.yaml` – base defaults
- `values-staging.yaml` – staging overrides
- `values-prod.yaml` – production overrides

## CI/CD

The `aks_cicd.yaml` workflow:

1. Logs into Azure (OIDC)
2. Ensures the resource group exists
3. Deploys AKS + ACR via Bicep
4. Attaches ACR to AKS
5. Builds and pushes the Docker image to ACR
6. Gets AKS credentials
7. Installs NGINX Ingress Controller via Helm
8. Deploys `aks-demo` via Helm (staging or prod)
9. Deploys Cloudflare Tunnel via Helm
10. Runs a smoke test against the public URL

Branches:

- `staging` → staging namespace + values
- `main` → prod namespace + values

## Rollback

To rollback a bad release in:

a. Production

```bash
helm history aks-demo -n prod
helm rollback aks-demo <REVISION> -n prod
```

b. Staging:

```bash
helm history aks-demo-staging -n staging
helm rollback aks-demo-staging <REVISION> -n staging
```


Notes
•	YAML validation in IDEs may flag Helm templates ({{ ... }}) as invalid. This is expected; the YAML is valid after Helm renders it.
•	Cloudflare credentials are stored in Kubernetes Secrets referenced by cloudflared.secretName.
