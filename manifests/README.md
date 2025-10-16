#Deploying DumbKV on Kubernetes (GKE Example)
This guide walks through deploying the **DumbKV** application on a **Kubernetes** cluster, using  **SQLite** or **PostgreSQL** as the backend database on different namespace and environment.

Although this example uses **Google Kubernetes Engine (GKE)**, the steps are compatible with most Kubernetes environments such as **Kind**, **EKS**, or **AKS**, with only minor differences.

---

## Prerequisites

Before deploying, ensure the following tools are installed and configured:

- A running Kubernetes cluster (e.g., GKE, EKS, AKS, Kind)
- kubectl
- helm
- kustomize
- Cluster admin access
- a domain name 
---

##  Step 1: Install Core Dependencies with Helm

We’ll install the following components using **Helm**:

1. NGINX Gateway Fabric
2. Cert-Manager
3. Prometheus Monitoring Stack

---

### 1. Install NGINX Gateway Fabric

Apply the required CRDs first:

kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.1.4" | kubectl apply -f -

Then install the NGINX Gateway Fabric Helm chart:

helm install ngf oci://ghcr.io/nginx/charts/nginx-gateway-fabric --create-namespace -n nginx-gateway

---

### 2. Install Cert-Manager

Add the Jetstack Helm repository and install Cert-Manager:

helm repo add jetstack https://charts.jetstack.io
helm repo update

helm install cert-manager jetstack/cert-manager --namespace cert-manager --create-namespace --version v1.19.0 --set config.enableGatewayAPI=true --set crds.enabled=true

---

### 3. Install Prometheus Stack

Add the Prometheus Helm repo and install the monitoring stack:

helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

helm install prometheus-stack prometheus-community/kube-prometheus-stack --namespace monitoring --create-namespace

---

## Directory Structure
```bash
manifests/
├── 1-k8s-resources/
│   ├── certificate.yaml
│   ├── cluster-issuer.yaml
│   ├── gateway.yaml
│   ├── httproute-grafana.yaml
│   ├── prometheus-instances.yaml
│   ├── rbac-prometheus.yaml
│   └── storage-class.yaml
│
├── base/
│   ├── deployment.yaml
│   ├── kustomization.yaml
│   ├── pvc.yaml
│   └── svc.yaml
│
├── components/
│   ├── kustomization.yaml
│   └── service-monitor.yaml
│
└── overlays/
    ├── postgres/
    │   ├── configmap.yaml
    │   ├── dep-patch.yaml
    │   ├── httproute.yaml
    │   ├── kustomization.yaml
    │   ├── pvc-patch.yaml
    │   ├── secrets.yaml
    │   ├── svc-headless.yaml
    │   └── svc-patch.yaml
    │
    └── sqlite/
        ├── configmap.yaml
        ├── deployment-patch.yaml
        ├── httproute.yaml
        ├── kustomization.yaml
        ├── namespace.yaml
        ├── pvc-patch.yaml
        └── svc-patch.yaml
```
---

## Step 2: Apply the k8s resources

kubectl apply -f manifests/1-k8s-resources

kubectl apply -k manifests/overlays/sqlite

kubectl apply -k manifests/overlays/postgres

---
## The gateway creates a load balancer

kubectl get gateway

Go to your DNS registrar and point the domain names, defined in manifests/1-k8s-resources/certificate.yaml to the ip address of the load balancer

---
## Ensure that the certificate is approve

kubectl get certificate 

Wait for some time for the certificate to be approved, the ready column will be true
---

## : Enable Monitoring
Access the grafana on the httproute defined in manifests/1-k8s-resources/httproute-grafana.yaml

Get the password and username
kubectl get secret -n monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-user}" | base64 --decode; echo
kubectl get secret -n monitoring prometheus-stack-grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo


Username: admin
Password: prom-operator

This gives you the default datasource, the next step would add the scraping datasource

---
## Enable Scraping of the metric
The components are used as reusable modules of scraping of the metric, there is a service monitor object that would be deployed in each overlay that imports it. Make sure the new operator is deployed in default since there is already an operator running in monitoring namespace from the earlier prometheus stack  
Use the FQDN of the prometheus operated headless svc as datasource to see your metric that is being scrapped


FQDN of the prom-operator headless service: http://prometheus-operated.default.svc.cluster.local:9090/
You can see the targets on the command line, by using 

kubectl run curl-test   --rm -it  \
--image=curlimages/curl:8.2.1 \
--restart=Never  \
-- curl -L http://prometheus-operated.default.svc.cluster.local:9090/api/v1/targets

##  Cleanup
kubectl delete -f manifests/1-k8s-resources
kubectl delete -k manifests/overlays/sqlite
kubectl delete -k manifests/overlays/postgres
helm uninstall ngf -n nginx-gateway
helm uninstall cert-manager -n cert-manager
helm uninstall prometheus-stack -n monitoring


---

##  References

- NGINX Gateway Fabric Docs: https://docs.nginx.com/nginx-gateway-fabric/
- Cert-Manager Documentation: https://cert-manager.io/docs/
- Kube-Prometheus Stack: https://github.com/prometheus-community/helm-charts/tree/main/charts/kube-prometheus-stack
- Kustomize Guide: https://kubectl.docs.kubernetes.io/guides/introduction/kustomize/
