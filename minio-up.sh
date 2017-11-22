#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

get_ingress_ip() {
    kubectl -n openfaas-fn describe service minio-lb | grep Ingress | awk '{ print $NF }'
}

gcloud compute disks create minio-disk --size=10GiB

kubectl -n openfaas-fn create secret generic minio-auth \
    --from-literal=key=ZBPIIAOCJRY9QLUVEHQO \
    --from-literal=secret=vMIoCaBu9sSg4ODrSkbD9CGXtq0TTpq6kq7psLuE

kubectl apply -f ./minio.yml

kubectl -n openfaas-fn expose deployment minio \
    --type=LoadBalancer \
    --name=minio-lb

kubectl -n openfaas-fn get all

until [[ "$(get_ingress_ip)" ]]
 do sleep 1;
 echo -n ".";
done

echo ""
echo "Minio External IP: $(get_ingress_ip)"
