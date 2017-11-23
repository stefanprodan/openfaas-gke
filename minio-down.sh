#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

kubectl delete -f ./minio.yml
kubectl -n openfaas-fn delete service minio-lb
kubectl -n openfaas-fn delete secret minio-auth
