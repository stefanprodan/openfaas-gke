#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

get_ingress_ip() {
    kubectl -n openfaas describe service caddy-lb | grep Ingress | awk '{ print $NF }'
}

kubectl apply -f ./faas.yml

kubectl -n openfaas create secret generic basic-auth \
    --from-literal=user=admin \
    --from-literal=password=admin

kubectl apply -f ./caddy.yml

kubectl -n openfaas expose deployment caddy \
    --type=LoadBalancer \
    --name=caddy-lb

kubectl -n openfaas get all

until [[ "$(get_ingress_ip)" ]]
 do sleep 1;
 echo -n ".";
done

echo ""
echo "External IP: $(get_ingress_ip)"

