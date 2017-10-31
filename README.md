# openfaas-gke

OpenFaaS on Google Container Engine

### GKE Setup

Before running the project you'll have to create a GCP service account key. 
Go to _Google Cloud Platform -> API Manager -> Credentials -> Create Credentials -> Service account key_ and 
chose JSON as key type. Rename the file to `account.json` and put it in the project root.
Add your SSH key under _Compute Engine -> Metadata -> SSH Keys_, also create a metadata entry named `sshKeys` 
with your public SSH key as value.

```bash
gcloud init
gcloud components install kubectl
```

```bash
gcloud container clusters create demo \
    --cluster-version=1.8.1-gke.0 \
    --zone=europe-west3-a \
    --additional-zones=europe-west3-b,europe-west3-c \
    --num-nodes=1 \
    --machine-type=n1-standard-1 \
    --scopes=default,storage-rw
```

```bash
gcloud container clusters delete demo -z=europe-west3-a 
```

### Setup credentials

```bash
gcloud container clusters get-credentials demo
```

```bash
kubectl create clusterrolebinding "cluster-admin-$(whoami)" \
    --clusterrole=cluster-admin \
    --user="$(gcloud config get-value core/account)"
```

Grant admin privileges to kubernetes-dashboard:

```bash
kubectl create clusterrolebinding kube-system-cluster-admin \
    --clusterrole cluster-admin \
    --user system:serviceaccount:kube-system:default
```

Access kubernetes-dashboard:

```bash
kubectl proxy --port=9099
# http://localhost:9099/ui
```

### Deploy OpenFaaS

```bash
kubectl apply -f ./faas.yml
```

View OpenFaaS pods

```bash
kubectl -n default get pods
```

Expose the gateway service:

```bash
kubectl expose deployment gateway --type=LoadBalancer --name=gateway-lb
```

Wait for an external IP to be allocated:

```bash
kubectl get services gateway-lb
```

Use the external IP to access the OpenFaaS gateway UI:

```bash
#http://<EXTERNAL-IP>:8080
```

### Deploy functions

Install OpenFaaS CLI:

```bash
curl -sL cli.openfaas.com | sudo sh
```

Deploy nodeinfo function:

```bash
faas-cli deploy --name=nodeinfo \
    --image=functions/nodeinfo:latest \
    --fprocess="node main.js" \
    --network=default \
    --gateway=http://<EXTERNAL-IP>:8080 
```

Invoke nodeinfo function:

```bash
echo -n "" | faas-cli invoke nodeinfo --gateway http://<EXTERNAL-IP>:8080
```

Load testing:

```bash
#install hey
go get -u github.com/rakyll/hey

#do 10K requests 
hey -n 1000 -c 10 -m POST -d "test" http://<EXTERNAL-IP>/function/nodeinfo
```

![scaling](https://github.com/stefanprodan/openfaas-gke/blob/master/screens/scaling.png)


