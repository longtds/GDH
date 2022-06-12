#!/bin/bash

# Clean up namespaces and resources
kubectl delete ns bigdata

# clean up node labels
for node in $(kubectl get node | grep -v NAME | awk '{print $1}'); do
    kubectl label node $node nn1- rm1- nn2- rm2- dn- nm- hive- spark- hs- kafka- trino-w- trino-m- zk- clickhouse- jn- shs-
done
