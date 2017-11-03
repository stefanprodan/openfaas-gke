#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

kubectl delete -f ./caddy.yml

kubectl delete namespace openfaas
kubectl delete namespace openfaas-fn
