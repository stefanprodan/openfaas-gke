#!/usr/bin/env bash

set -o errexit
set -o pipefail
set -o nounset

get_ingress_ip() {
    kubectl -n openfaas-fn describe service minio-lb | grep Ingress | awk '{ print $NF }'
}

kubectl -n openfaas-fn create secret generic minio-auth \
    --from-literal=key=ZBPIIAOCJRY9QLUVEHQO \
    --from-literal=secret=vMIoCaBu9sSg4ODrSkbD9CGXtq0TTpq6kq7psLuE

kubectl apply -f ./minio.yml

kubectl -n openfaas-fn expose deployment minio \
    --type=LoadBalancer \
    --name=minio-lb

until [[ "$(get_ingress_ip)" ]]
 do sleep 1;
 echo -n ".";
done

kubectl -n openfaas-fn get all | grep minio

IP=$(get_ingress_ip)
echo ""
echo "Minio External IP: ${IP}"

mc config host add gcp http://${IP}:9000 ZBPIIAOCJRY9QLUVEHQO vMIoCaBu9sSg4ODrSkbD9CGXtq0TTpq6kq7psLuE
mc mb gcp/colorization
mc cp test_image_bw.jpg gcp/colorization
