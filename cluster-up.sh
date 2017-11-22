#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

gcloud container clusters create demo \
    --cluster-version=1.8.3-gke.0 \
    --zone=europe-west3-a \
    --additional-zones=europe-west3-b,europe-west3-c \
    --num-nodes=1 \
    --machine-type=n1-standard-1 \
    --scopes=default,storage-rw

gcloud container clusters get-credentials demo

kubectl create clusterrolebinding "cluster-admin-$(whoami)" \
    --clusterrole=cluster-admin \
    --user="$(gcloud config get-value core/account)"

