#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

get_gateway_ip() {
    kubectl -n openfaas describe service caddy-lb | grep Ingress | awk '{ print $NF }'
}

# validate inputs
if [ -z "$basic_auth_user" ]; then
 echo "basic_auth_user is required"
 exit 1
fi

if [ -z "$basic_auth_password" ]; then
 echo "basic_auth_password is required"
 exit 1
fi

# create namespaces
kubectl apply -f ./namespaces.yaml

# create basic-auth secrets
kubectl -n openfaas create secret generic basic-auth \
    --from-literal=user=${basic_auth_user} \
    --from-literal=password=${basic_auth_password}

# deploy OpenFaaS
kubectl apply -f ./openfaas

# deploy Caddy LB
kubectl apply -f ./caddy

# wait for the public IP to assigned
until [[ "$(get_gateway_ip)" ]]
 do sleep 1;
 echo -n ".";
done
echo "."
gateway_ip=$(get_gateway_ip)
echo "OpenFaaS Gateway IP: ${gateway_ip}"

# save OpenFaaS credentials
echo ${basic_auth_password} | faas-cli login -u ${basic_auth_user} --password-stdin --gateway=http://${gateway_ip}

