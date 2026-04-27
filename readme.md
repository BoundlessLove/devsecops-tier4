
# AIM

Local Kubernetes setup using Docker Desktop and Cloudflare.

# HOW TO SETUP USING DOCKER DESKTOP LOCALLY

## New Cluster in Windows

a. Create cluster with Load Balancer

<i>Pre req: Launch Docker Desktop.</i>

<i>Assumption: Your Kubernetes setup is running a Service that uses the load balancer.  </i>

```
i.   [Navigate to your project in powershell]

ii.  Create Kubernetes cluster k3d cluster create aks-local --config k3d-aks-local.yaml

iii. Confirm cluster creation k3d cluster list

iv.  Start cluster 'k3d cluster start [cluster name]'
 ```

b. Deploy Service on Kubernetes Cluster

```
i.   cd app

ii.  docker build -t aks-demo:v1 .

iii. cd ..

iv.  k3d image import aks-demo:v1 -c aks-local

v.   kubectl apply -f k8s/deployment.local.yaml

vi.  kubectl apply -f k8s/service.yaml
```

c. Verify deployment and launch

```

i. kubectl get pods

ii. kubectl get svc aks-demo-service. 

iii. In version 0.3, You should see service type of load balancer. It is a traefik load balancer. You can see it via:

- kubectl get pods -n kube-system | findstr traefik

iv. [Navigate to] http://localhost:8080.

```

<i>Note: Version 0.4 onwards, traefik load balancer is used and CLOUDFLARE tunnel container is added and applied to cluster with an ingress that exposes the cluster's service. Version 0.5 improves on version 0.4 by replacing load balancer with cluster IP, adding a nginx server and an ingress that exposes only the nginx server.</i>

## Existing Cluster

a. Start cluster

<i>Pre req: Open Docker Desktop.</i>

```
i. Confirm cluster creation by running "k3d cluster list",

ii.  Start cluster 'k3d cluster start [cluster name]',

b. Verify deployment and launch

i. kubectl get pods

ii. kubectl get svc aks-demo-service. You should see service type of load balancer. It is a traefik load balancer. You can see it via:

- kubectl get pods -n kube-system | findstr traefik

iv. [Navigate to] http://localhost:8080.
```



## Version 0.1
19 April 2026 17:00 - Cluster working locally on Docker desktop.

## Version 0.2
19 April 2026 19:37 - Pre-req is creating an Azure Container Registry (ACR) and an Azure Kubernetes Cluster (containing the ACR). First attempt at CICD AKS. 


## Version 0.3
24 April 2026 16:36 - Kubernetes working locally with k3d's Traefik load balancer. Steps to setup have been documented in Readme.md file under heading 'local dev'.  

### Version 0.3.1
24 April 2026 16:39 - Added identification of the load balancer as a 'traefik' one - automatically generated in k3d.

## Version 0.4
26 April 2026 20:12 - Kubernetes working locally with https from domain staging.systematicdefence.tech. It uses the following model:

- Cloudflare → Tunnel → cloudflared → aks-demo-service → Pods

<i>Note: In above case traefik load balancer is being used and ingress is not involved.</i>

![Working https Screenshot without Ingress](./screenshots/CloudfareTalkingToAKS-Service.jpg)

Issue is that Azure Kubernetes does not accept traefik loadbalancer, and while this setup  works, but it:

•	Bypasses Ingress rules

•	Bypasses NGINX features

•	Bypasses path routing

•	Bypasses host routing

•	Bypasses TLS termination

•	Bypasses rate limiting

•	Bypasses WAF rules

•	Bypasses rewrite rules

See Annex A for process.

## Version 0.5

26 April 2026 20:13 Objective: Cloudflare → Tunnel → cloudflared → Ingress → Service → Pods

![Working https Screenshot with cluster ingress](./screenshots/CloudfareTalkingToLocalKubernetesClusterViaClusterIngress.jpg)

See Annex A for process.

### Version 0.5.1

26 April 2026 20:14 updates to readme to incorporate cloudflared-deployment.yaml to setup and in Annex A.

## Version 1.0

26 April 2026 15:18 updates to readme.md for publishing.

## Version 1.1

27 April 2026 16:30 First attempt at turning local setup to AKS.

a. Added Following secrets to Github repo:

i) AZURE_CLIENT_ID
ii) AZURE_TENANT_ID
iii) AZURE_SUBSCRIPTION_ID
vi) AZURE_CONTAINER_REGISTRY
v) AZURE_RESOURCE_GROUP
vi) CLUSTER_NAME
vii) IMAGE_NAME
viii) IMAGE_TAG
ix) LOCATION


 b. Adding github workflow aks_cicd.yaml from devsecops-tier3 dev branch, nativising it by adding trigger point as commit to Main branch.
 
 c. Creating a federated-credential for the pipeline
 
 ```

PS /home/jay> az ad app federated-credential create --id <App registeration Client ID>   --parameters '{
    "name": "github-devsecops-tier4-aks",
    "issuer": "https://token.actions.githubusercontent.com",
    "subject": "repo:BoundlessLove/devsecops-tier4:ref:refs/heads/main",
    "audiences": ["api://AzureADTokenExchange"]
  }'

```

d. Adding a Nginx controller 

In a local cluster, it was see in dev branch of DevSecOps-Tier2 how this controller was created for the k3s cluster. However, in aks this is far more complicated as the Nginx controller must also implement:

- RBAC  
- ServiceAccount  
- ClusterRole  
- ClusterRoleBinding  
- Correct controller args  
- Correct labels  
- Readiness/liveness probes  

Otherwise, NGINX never bound to port 80 meaning cloudflared would forward traffic to a dead endpoint, returning something like a  **530 Origin Unreachable**. Hence, Helm step instead is added to setup the controller in the aks_cicd.yaml file in STEP G.i).



e. Adding BICEP files to create the infrastructure from devsecops-tier3 dev branch

f. Updating aks_cicd.yaml to remove helm deployment steps and replace them with docker deployment

g. Creating aks manifests

i) .github/workflows/aks_cicd.yaml

```yaml
name: Build and Deploy to AKS

on:
  push:
    branches:
      - main

permissions:
  id-token: write
  contents: read

jobs:
  deploy:
    runs-on: ubuntu-latest

    env:
      ACR_NAME: ${{ secrets.AZURE_CONTAINER_REGISTRY }}
      RESOURCE_GROUP: ${{ secrets.AZURE_RESOURCE_GROUP }}
      AKS_NAME: ${{ secrets.CLUSTER_NAME }}
      LOCATION: ${{ secrets.AZURE_LOCATION }}
      IMAGE_NAME: ${{ secrets.IMAGE_NAME }}
      IMAGE_TAG: ${{ secrets.IMAGE_TAG }}

    steps:
    - name: Checkout
      uses: actions/checkout@v4

    - name: Azure Login (OIDC)
      uses: azure/login@v2
      with:
        client-id: ${{ secrets.AZURE_CLIENT_ID }}
        tenant-id: ${{ secrets.AZURE_TENANT_ID }}
        subscription-id: ${{ secrets.AZURE_SUBSCRIPTION_ID }}

    - name: Force Azure CLI to use stable AKS API version
      run: |
        az config set defaults.aks.api-version=2024-11-01

    # 0. Ensure Resource Group exists (via Bicep)
    - name: Ensure Resource Group exists
      run: |
        az deployment sub create \
          --location "$LOCATION" \
          --template-file infra/create-rg.bicep \
          --parameters rgName="$RESOURCE_GROUP" rgLocation="$LOCATION"


    # 1. Deploy Infra via Bicep
    - name: Deploy ACR + AKS via Bicep
      run: |
        az deployment group create \
          --resource-group "$RESOURCE_GROUP" \
          --name "aks-infra-deploy" \
          --template-file infra/main.bicep \
          --parameters acrName="$ACR_NAME" aksName="$AKS_NAME"

    - name: Attach ACR to AKS
      run: |
        az aks update \
          --resource-group "$RESOURCE_GROUP" \
          --name "$AKS_NAME" \
          --attach-acr "$ACR_NAME"

    # 2. Build & Push Image
    - name: Build and Push Image to ACR
      run: |
        az acr login --name "$ACR_NAME"
        IMAGE="$ACR_NAME.azurecr.io/$IMAGE_NAME:$IMAGE_TAG"
        echo "IMAGE=$IMAGE" >> $GITHUB_ENV
        docker build -t "$IMAGE" .
        docker push "$IMAGE"

    # 3. Connect to AKS
    - name: Get AKS Credentials
      run: |
        az aks get-credentials \
          --resource-group "$RESOURCE_GROUP" \
          --name "$AKS_NAME" \
          --overwrite-existing

    # 4. Install NGINX Ingress Controller ( ingress-nginx.aks.yaml)
    - name: Apply Ingress Controller
      run: |
        helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
        helm repo update

        helm upgrade --install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.service.type=ClusterIP \
        --set controller.ingressClassResource.name=nginx \
        --set controller.ingressClassResource.controllerValue="k8s.io/ingress-nginx"


    # 5. Deploy Application + Ingress + Cloudflared
    - name: Apply Kubernetes Manifests
      run: |
        kubectl apply -f k8s/app/deployment.aks.yaml
        kubectl apply -f k8s/app/service.aks.yaml
        kubectl apply -f k8s/ingress/staging-ingress-nginx.aks.yaml
        kubectl apply -f k8s/cloudflared/cloudflared-deployment.aks.yaml

    # 6. Verify successful deployment
    - name: Smoke test HTTP endpoint
      run: |
        echo "Testing https://staging.systematicdefence.tech"
        RESPONSE=$(curl -fsSL https://staging.systematicdefence.tech)
        echo "Response: $RESPONSE"
        if [ "$RESPONSE" != "Hello from aks-demo running on k3d!" ]; then
          echo "❌ Unexpected response"
          exit 1
        fi
        echo "✅ Response matched expected output"

```


ii) k8s/ingress/staging-ingress-nginx.aks.yaml 

```
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: staging-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: staging.systematicdefence.tech
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: aks-demo-service
            port:
              number: 80

```


iii) k8s/app/service.aks.yaml 

As my ingress above routes to port 80, so service should also expose port 80. Further I move it to cluster IP from Load Balancer type, as is required by nginx:


```
apiVersion: v1
kind: Service
metadata:
  name: aks-demo-service
spec:
  type: ClusterIP
  selector:
    app: aks-demo
  ports:
    - port: 80
      targetPort: 8080

```



h. Final currently usable structure of repository

```
infra/
  main.bicep

k8s/
  app/
    deployment.aks.yaml
    service.aks.yaml

  ingress/
    staging-ingress-nginx.aks.yaml
    ingress-nginx.aks.yaml   # corrected AKS version

  cloudflared/
    cloudflared-deployment.aks.yaml
    config.yml
    credentials/
      credentials.json

.github/
  workflows/
    aks-cicd.yml

Dockerfile
server.js

```

h. INFRASTRUCTURE AS A SERVICE: Replacing Azure CLI commands for creating infrastructure in pipeline with BICES files

i) Resource Group

'Ensure Resource Group' step would be replaced by:  

```
# 0. Ensure Resource Group exists (via Bicep)
- name: Ensure Resource Group exists
  run: |
    az deployment create \
      --location "$LOCATION" \
      --template-file infra/create-rg.bicep \
      --parameters rgName="$RESOURCE_GROUP" rgLocation="$LOCATION"

          
```
It would now refer to infra/create-rg.bicep:

```bicep

targetScope = 'resourceGroup'

@description('Name of the resource group')
param rgName string

@description('Location of the resource group')
param rgLocation string

resource rg 'Microsoft.Resources/resourceGroups@2021-04-01' = {
  name: rgName
  location: rgLocation
}


```
 

## Annex A - How to create a connection to Cloudflare

### SUMMARY

STEP 1-6 creates a temporary linux container, in order to create a Cloudflare credentials. This works because Cloudflare requires:

•	A Linux environment

•	A browser login

•	A writable filesystem

A Docker container satisfies all three. Further, since it is outside Kubernetes, Cloudflare allows the JSON to be generated. STEP 7 sets up a container in the kubernetes cluster that hosts a connection to CLOUDFLARE. It uses either an ingress which connects the cluster's service endpoint to CLOUDFLARE (Load Balancer) or sets up a nginx server that is exposed to CLOUDFLARE (Cluster IP). The latter is better as it isolates the cluster, exposing endpoints only through the nginx server and also is able to use extra features added by the use of CLOUDFLARE like DDOS protection. Step 8 deploys the CLOUDFLARE container to the cluster and tells the cluster about it. STEP 9 perfoems verification.




### PRE-REQ

a. Cloudflare account exists. 

b. Domain purchased. Domain DNS has been moved to Cloudflare.

c. Target sub domain exists in hosting provider. No A record exists for it in Cloudflare DNS, i.e. staging.systematicdefence.tech  

d. Project structure:

i) Example structure:

```

k8s/

  cloudflared/

    config.yml

    credentials/

      aa1d965e-63ed-4002-be37-7a659a915cdb.json   # DO NOT COMMIT

      cert.pem                                    # DO NOT COMMIT

  ingress/

    ingress-nginx.yaml

    staging-ingress.yaml

  deployments/

    aks-demo-deployment.yaml

    aks-demo-service.yaml
    
```

ii) Add a .gitignore entry:

k8s/cloudflared/credentials/*


### STEP 1 — Run a temporary Linux container on your PC

This container will act like the “Linux VM” but without needing a VM.

a. Run:

docker run -it --name cloudflared-bootstrap ubuntu:22.04 bash

b. Inside the container:

apt update

apt install -y wget curl nano
 
### STEP 2 — Install cloudflared inside the container

wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64

mv cloudflared-linux-amd64 /usr/local/bin/cloudflared

chmod +x /usr/local/bin/cloudflared


Note: At this point the container hung. So I closed the powershell window, even though the container was still running. I reentered container via following commands on host:

a. [View docker name] docker ps –a

b. [Run docker command, where ‘-it’ is ‘interactive terminal’] docker exec –it cloudflared-bootstrap /bin/bash 

 
### STEP 3 — Authenticate

a. Inside the container, run:

- cloudflared tunnel login

This opens a URL in your host browser.

b. Log in → select your domain. This generates:

/root/.cloudflared/cert.pem
 
### STEP 4 — Create a new connector for your existing tunnel

a. Inside the container, run:

- cloudflared tunnel create staging-connector

This generates:

/root/.cloudflared/<UUID>.json

This is the JSON you need for Kubernetes.

### STEP 5 — Copy the JSON out of the container

From your host:

C:\Users\moose\>: docker cp cloudflared-bootstrap:/root/.cloudflared ./

You now have:

./.cloudflared/<UUID>.json

./.cloudflared/cert.pem

### STEP 6 — Delete the bootstrap container

docker rm -f cloudflared-bootstrap

### STEP 7 - Setup config.yml and docker-compose.yml to create a cloudflare container to host the tunnel

This can be done via CloudFlare routing through exposed ingress or directly through the exposed service. These are difference architectures:

- Ingress: Cloudflare → Tunnel → cloudflared → NGINX Ingress Controller → Services → Pods
- Service: Cloudflare → Tunnel → cloudflared → aks-demo-service → Pods

<i>Note: To get the benefits of Cloudflare, the ingress path is preferred. See Release Version 0.5</i>




#### a) Tunnel uses Service

Place them in the folder where the json credential file is placed. In this case, it is c:/cloudflared. 

Note: In your editor encoding replace <CRLF> with <LF>

##### config.yml

```yaml
tunnel: <tunnel-id>
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: staging.systematicdefence.tech
    service: http://aks-demo-service.default.svc.cluster.local:80
  - service: http_status:404

```
---
##### docker-compose.yml

``` yaml
version: "3.8"

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared-tunnel
    restart: unless-stopped
    command: tunnel run
    volumes:
      - ./config.yml:/etc/cloudflared/config.yml
      - ./<tunnel-id>.json:/etc/cloudflared/<tunnel-id>.json
    network_mode: bridge

```
---
##### ingress/staging-ingress-via-service.local.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: staging-ingress
spec:
  rules:
  - host: staging.systematicdefence.tech
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: aks-demo-service
            port:
              number: 8080

```
---
#### b) Tunnel uses Ingress

##### The plan is:

•	Install NGINX Ingress Controller

•	Expose only the Ingress Controller via LoadBalancer

•	All apps sit behind the Ingress

##### Benefit is:

- Cloudflared sends traffic to the NGINX Ingress Controller, not the app. NGINX applies routing rules, TLS, rewrites, etc. So, it is possible to get full AKS parity and more apps can be added without touching cloudflared

Further,  is the standard Production pattern as it leads to zero public exposure, i.e.:

•	NO need for a public LoadBalancer in AKS

•	NO need for a public IP

•	NO need to expose NGINX to the internet

•	NO need to open ports

•	NO need to pay for Azure LB

Your AKS/local cluster becomes 100% private, 0 public IPs and 0 attack surface, as Cloudflare Tunnel becomes the only entry point.

Note: In your editor encoding replace <CRLF> with <LF>

##### ingress/ingress-nginx.local.yml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: ingress-nginx

---

apiVersion: helm.cattle.io/v1
kind: HelmChart
metadata:
  name: ingress-nginx
  namespace: ingress-nginx
spec:
  chart: ingress-nginx
  repo: https://kubernetes.github.io/ingress-nginx
  targetNamespace: ingress-nginx
  version: 4.10.0
  valuesContent: |-
    controller:
      service:
        type: ClusterIP

```
---        
##### ingress/staging-ingress-nginx.local.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: staging-ingress
  namespace: default
  annotations:
    kubernetes.io/ingress.class: nginx
spec:
  rules:
  - host: staging.systematicdefence.tech
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: aks-demo-service
            port:
              number: 80
```
---
##### config.yml

```yaml
tunnel: <tunnel-id>
credentials-file: /etc/cloudflared/credentials.json

ingress:
  - hostname: staging.systematicdefence.tech
    service: http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80
  - service: http_status:404
```
---
##### docker-compose.yml

```yaml

version: "3.8"

services:
  cloudflared:
    image: cloudflare/cloudflared:latest
    container_name: cloudflared-tunnel
    restart: unless-stopped
    command: tunnel run
    volumes:
      - ./config.yml:/etc/cloudflared/config.yml
      - ./<tunnel-id>.json:/etc/cloudflared/<tunnel-id>.json
    network_mode: bridge
```
---
#### c) Common file for Tunnel

The Deployment that:

i) Runs cloudflared inside your cluster

ii) Connects to Cloudflare Tunnel

iii) Forwards traffic to NGINX Ingress Controller

iv) Makes your cluster private

v) Removes the need for public LoadBalancers

It is essential as without this Deployment:

i) Your tunnel would not connect

ii) Your domain would not route

iii) Your cluster would not be reachable

##### k8s/cloudflared-deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cloudflared
  namespace: default
  labels:
    app: cloudflared
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cloudflared
  template:
    metadata:
      labels:
        app: cloudflared
    spec:
      containers:
      - name: cloudflared
        image: cloudflare/cloudflared:latest
        args:
          - tunnel
          - --config
          - /etc/cloudflared/config.yml
          - run
        volumeMounts:
        - name: config
          mountPath: /etc/cloudflared/config.yml
          subPath: config.yml
        - name: creds
          mountPath: /etc/cloudflared/credentials.json
          subPath: credentials.json
      volumes:
      - name: config
        configMap:
          name: cloudflared-config
      - name: creds
        secret:
          secretName: cloudflared-credentials

```

### STEP 8 - Deploy cloudflared inside Kubernetes

You could be deploying cloudflared for first time or updating existing:

#### i. New Deployment

Note: Extracted .json from step 4 will be used. 

a. Create secret:

```
kubectl create secret generic cloudflared-credentials `
  --from-file=credentials.json=k8s/cloudflared/credentials/aa1d965e-63ed-4002-be37-7a659a915cdb.json
  
kubectl create secret generic cloudflared-cert \
  --from-file=cert.pem=k8s/cloudflared/credentials/cert.pem
  ```

b. Update config.yml and docker-compose.yml in C:\cloudflared (Update the reference to the tunnel id * 3).

c. Create configmap and tell the cluster of this new pod:

```kubectl create configmap cloudflared-config --from-file=k8s/cloudflared/config.yml

kubectl apply -f k8s/cloudflared/cloudflared-deployment.yaml
```
  

#### ii. Update Existing Deployment

a.  Apply the updated config


```kubectl delete configmap cloudflared-config

kubectl create configmap cloudflared-config --from-file=k8s/cloudflared/config.yml

kubectl rollout restart deployment cloudflared

```
  
You should now hit your app through:

Cloudflare → Tunnel → cloudflared → NGINX → Service → Pods

### STEP 9 - Verify 

a) Check Cloudflared logs:

```

kubectl logs -f deployment/cloudflared
```

You should see:

- "Connected to Cloudflare.

- "Proxying tunnel requests to http://ingress-nginx-controller.ingress-nginx.svc.cluster.local:80"


b) Test externally:

curl https://staging.systematicdefence.tech




