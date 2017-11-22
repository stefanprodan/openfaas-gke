#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

get_ingress_ip() {
    kubectl -n openfaas describe service gateway-lb | grep Ingress | awk '{ print $NF }'
}

kubectl apply -f ./ns.yml,faas-async.yml,nats.yml,prom.yml

kubectl -n openfaas expose deployment gateway \
    --type=LoadBalancer \
    --name=gateway-lb

kubectl -n openfaas get all

until [[ "$(get_ingress_ip)" ]]
 do sleep 1;
 echo -n ".";
done

echo "External IP: $(get_ingress_ip)"

