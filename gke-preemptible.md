# Running multiple OpenFaaS instances on GKE

This is step-by-step guide on setting up OpenFaaS on GKE with the following specs:
* two OpenFaaS instances isolated with network policies
* a dedicated node pool for OpenFaaS core services
* a dedicated preemptible node pool for OpenFaaS functions 
* secure OpenFaaS ingress with Let's Encrypt TLS and authentication

### GKE Cluster Setup 

Create a cluster with a node pool of minimum two nodes:

```bash
k8s_version=$(gcloud container get-server-config --format=json | jq -r '.validNodeVersions[0]')

gcloud container clusters create openfaas \
    --cluster-version=${k8s_version} \
    --zone=europe-west3-a \
    --num-nodes=2 \
    --enable-autoscaling --min-nodes=2 --max-nodes=4 \
    --machine-type=n1-highcpu-4 \
    --no-enable-cloud-logging \
    --disk-size=30 \
    --enable-autorepair \
    --enable-network-policy \
    --scopes=gke-default,compute-rw,storage-rw
```

Create a preemptible node pool with a single node:

```bash
gcloud container node-pools create fn-pool \
    --cluster=openfaas \
    --preemptible \
    --node-version=${k8s_version} \
    --zone=europe-west3-a \
    --num-nodes=1 \
    --machine-type=n1-highcpu-4 \
    --disk-size=30 \
    --enable-autorepair \
    --scopes=gke-default,compute-rw,storage-rw
```

Preemtible VMs will be terminated and replaced after a maximum of 24 hours. 
In order to avoid all nodes to be terminated at the same time, 
wait for 30 minutes and scale up the fn pool to two nodes: 

```bash
gcloud container clusters resize openfaas \
    --size=2 \
    --node-pool=fn-pool \
    --zone=europe-west3-a 
```

Set up credentials for `kubectl`:

```bash
gcloud container clusters get-credentials europe -z=europe-west3-a
```

Create a cluster admin user:

```bash
kubectl create clusterrolebinding "cluster-admin-$(whoami)" \
    --clusterrole=cluster-admin \
    --user="$(gcloud config get-value core/account)"
```

This default-pool nodes are labeled with `cloud.google.com/gke-nodepool=default-pool` and 
the preemptible nodes with `cloud.google.com/gke-nodepool=fn-pool` and `cloud.google.com/gke-preemptible=true`.

When a VM is preempted it gets logged here:

```bash
gcloud compute operations list | grep compute.instances.preempted
```

### Setup Helm, Tiller, Ingress and Let's Encrypt provider 

Install Helm CLI with Homebrew:

```bash
brew install kubernetes-helm
```

Create a service account and a cluster role binding for Tiller:

```bash
kubectl -n kube-system create sa tiller

kubectl create clusterrolebinding tiller-cluster-rule \
    --clusterrole=cluster-admin \
    --serviceaccount=kube-system:tiller 
```

Deploy Tiller on the openfaas cluster:

```bash
helm init --skip-refresh --upgrade --service-account tiller
```

When exposing OpenFaaS on the internet you should enable HTTPS to encrypt all traffic. 
To do that you'll need the following tools:

* [Heptio Contour](https://github.com/heptio/contour) as Kubernetes Ingress controller
* [JetStack cert-manager](https://github.com/jetstack/cert-manager) as Let's Encrypt provider 

Heptio Contour is an ingress controller based on [Envoy](https://www.envoyproxy.io) reverse proxy that supports dynamic configuration updates. 
Install Contour with:

```bash
kubectl apply -f https://j.hept.io/contour-deployment-rbac
```

Find the Contour address with:

```yaml
kubectl -n heptio-contour describe svc/contour | grep Ingress | awk '{ print $NF }'
```

Go to your DNS provider and create an `A` record for each OpenFaaS instance:

```bash
$ host openfaas.example.com
openfaas.example.com has address 35.197.248.216

$ host openfaas-dev.example.com
openfaas-dev.example.com has address 35.197.248.217
```

Install cert-manager with Helm:

```bash
helm install --name cert-manager \
    --namespace kube-system \
    stable/cert-manager
```

Create a cluster issuer definition (replace `EMAIL@DOMAIN.NAME` with a valid email address):

```yaml
apiVersion: certmanager.k8s.io/v1alpha1
kind: ClusterIssuer
metadata:
  name: letsencrypt
spec:
  acme:
    email: EMAIL@DOMAIN.NAME
    http01: {}
    privateKeySecretRef:
      name: letsencrypt-cert
    server: https://acme-v02.api.letsencrypt.org/directory
```

Save the above resource as `letsencrypt-issuer.yaml` and then apply it:

```bash
kubectl apply -f ./letsencrypt-issuer.yaml
```


### Setup OpenFaaS dev and prod network policies

Create the OpenFaaS dev and prod namespaces:

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: openfaas-dev
  labels:
    role: openfaas-system
    access: openfaas-system
---
apiVersion: v1
kind: Namespace
metadata:
  name: openfaas-dev-fn
---
apiVersion: v1
kind: Namespace
metadata:
  name: openfaas-prod
  labels:
    role: openfaas-system
    access: openfaas-system
---
apiVersion: v1
kind: Namespace
metadata:
  name: openfaas-prod-fn
```

Save the above resource as `openfaas-ns.yaml` and then apply it:

```bash
kubectl apply -f ./openfaas-ns.yaml
```

All ingress traffic from the `heptio-contour` namespace to both OpenFaaS systems:

```bash
kubectl label namespace heptio-contour access=openfaas-system
``` 

Create network policies to isolate the OpenFaaS core services from the function namespaces:

```yaml
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: openfaas-dev
  namespace: openfaas-dev
spec:
  policyTypes:
  - Ingress
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          access: openfaas-system
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: openfaas-dev-fn
  namespace: openfaas-dev-fn
spec:
  policyTypes:
  - Ingress
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          role: openfaas-system
---
kind: NetworkPolicy
apiVersion: networking.k8s.io/v1
metadata:
  name: openfaas-prod
  namespace: openfaas-prod
spec:
  policyTypes:
  - Ingress
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          access: openfaas-system
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: openfaas-prod-fn
  namespace: openfaas-prod-fn
spec:
  policyTypes:
  - Ingress
  podSelector: {}
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          role: openfaas-system
```

Save the above resource as `network-policies.yaml` and then apply it:

```bash
kubectl apply -f ./network-policies.yaml
```

Note that the above configuration will prohibit functions from calling each other or from reaching the
OpenFaaS core services.

### Install OpenFaaS dev instance

Generate a random password and create an OpenFaaS credentials secret:

```bash
password=$(head -c 12 /dev/urandom | shasum | cut -d' ' -f1)

kubectl -n openfaas-dev create secret generic basic-auth \
--from-literal=basic-auth-user=admin \
--from-literal=basic-auth-password=$password
```

Create the dev configuration (replace example.com with your own DNS):

```yaml
functionNamespace: openfaas-dev-fn
basic_auth: true
operator:
  create: true
  createCRD: true
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: "contour"
    certmanager.k8s.io/cluster-issuer: "letsencrypt"
    contour.heptio.com/request-timeout: "30s"
    contour.heptio.com/num-retries: "3"
    contour.heptio.com/retry-on: "gateway-error"
  hosts:
    - host: openfaas-dev.example.com
      serviceName: gateway
      servicePort: 8080
      path: /
  tls:
    - secretName: openfaas-cert
      hosts:
      - openfaas-dev.example.com
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: cloud.google.com/gke-preemptible
          operator: DoesNotExist
```

Save the above file as `openfaas-dev.yaml` and install OpenFaaS dev instance from the project helm repository:

```bash
helm repo add openfaas https://openfaas.github.io/faas-netes/

helm upgrade openfaas-dev --install openfaas/openfaas \
    --namespace openfaas-dev  \
    -f openfaas-dev.yaml
```

### Install OpenFaaS prod instance

Generate a random password and create the basic-auth secret:

```bash
password=$(head -c 12 /dev/urandom | shasum | cut -d' ' -f1)

kubectl -n openfaas-prod create secret generic basic-auth \
--from-literal=basic-auth-user=admin \
--from-literal=basic-auth-password=$password
```

Create the production configuration (replace example.com with your own DNS):

```yaml
functionNamespace: openfaas-prod-fn
basic_auth: true
operator:
  create: true
  createCRD: false
ingress:
  enabled: true
  annotations:
    kubernetes.io/ingress.class: "contour"
    certmanager.k8s.io/cluster-issuer: "letsencrypt"
    contour.heptio.com/request-timeout: "30s"
    contour.heptio.com/num-retries: "3"
    contour.heptio.com/retry-on: "gateway-error"
  hosts:
    - host: openfaas.example.com
      serviceName: gateway
      servicePort: 8080
      path: /
  tls:
    - secretName: openfaas-cert
      hosts:
      - openfaas.example.com
affinity:
  nodeAffinity:
    requiredDuringSchedulingIgnoredDuringExecution:
      nodeSelectorTerms:
      - matchExpressions:
        - key: cloud.google.com/gke-preemptible
          operator: DoesNotExist
```

Note that `operator.createCRD` is set to false since the `functions.openfaas.com` custom resource definition is 
already present on the cluster.

Save the above file as `openfaas-prod.yaml` and install OpenFaaS instance from the project helm repository:

```bash
helm upgrade openfaas-prod --install openfaas/openfaas \
    --namespace openfaas-prod  \
    -f openfaas-prod.yaml
```

### Manage OpenFaaS functions with kubectl 

Using the OpenFaaS CRD you can define functions as a Kubernetes custom resource:

```yaml
apiVersion: openfaas.com/v1alpha2
kind: Function
metadata:
  name: certinfo
spec:
  name: certinfo
  image: stefanprodan/certinfo:latest
  labels:
    com.openfaas.scale.min: "2"
    com.openfaas.scale.max: "12"
    com.openfaas.scale.factor: "4"
  limits:
    cpu: "1000m"
    memory: "128Mi"
  requests:
    cpu: "10m"
    memory: "64Mi"
  constraints:
    - "cloud.google.com/gke-preemptible=true"
```

Save the above resource as `certinfo.yaml` and use `kubectl` to deploy the function in both instances:

```bash
kubectl -n openfaas-dev-fn apply -f certinfo.yaml
kubectl -n openfaas-prod-fn apply -f certinfo.yaml
```


