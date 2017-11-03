#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

get_ingress_ip() {
    kubectl -n openfaas describe service caddy-lb | grep Ingress | awk '{ print $NF }'
}

gcloud config get-value core/account

kubectl apply -f ./faas-ns.yml

kubectl -n openfaas create secret generic basic-auth \
    --from-literal=user=admin \
    --from-literal=password=admin

kubectl -n openfaas apply -f ./caddy-ns.yml

kubectl -n openfaas expose deployment caddy \
    --type=LoadBalancer \
    --name=caddy-lb

kubectl -n openfaas get all

until [[ "$(get_ingress_ip)" ]]
 do sleep 1;
 echo -n ".";
done

echo "External IP: $(get_ingress_ip)"

