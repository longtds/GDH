#!/bin/bash

source config.sh

# create namespace
echo "kind: Namespace
apiVersion: v1
metadata:
  name: ${bigdata_namespace}
  labels:
    app.kubernetes.io/name: gdmp" | kubectl apply -f -

kubectl config set-context --current --namespace=${bigdata_namespace}

# --------------------------Start configuring node labels-----------------#
for node in ${zookeeper_node[@]}; do
    kubectl label node --overwrite ${node} zk=true
done

for node in ${namenode1_node[@]}; do
    kubectl label node --overwrite ${node} nn1=true rm1=true hs=true
done

for node in ${namenode2_node[@]}; do
    kubectl label node --overwrite ${node} nn2=true rm2=true
done

for node in ${datanode_node[@]}; do
    kubectl label node --overwrite ${node} dn=true nm=true
done

for node in ${journal_node[@]}; do
    kubectl label node --overwrite ${node} jn=true
done

for node in ${hive_node[@]}; do
    kubectl label node --overwrite ${node} hive=true
done

for node in ${spark_node[@]}; do
    kubectl label node --overwrite ${node} spark=true shs=true
done

for node in ${kafka_node[@]}; do
    kubectl label node --overwrite ${node} kafka=true
done

for node in ${trino_master_node[@]}; do
    kubectl label node --overwrite ${node} trino-m=true
done

for node in ${trino_worker_node[@]}; do
    kubectl label node --overwrite ${node} trino-w=true
done

for node in ${clickhouse_node[@]}; do
    kubectl label node --overwrite ${node} clickhouse=true
done

# --------------------------End configuring node labels-------------------#

# --------------------------Start function--------------------------------#
# Check if the service is ready
check_service() {
    until curl -I $1; do
        echo "waiting for $1 to be ready"
        sleep 10
    done
}
# Check if the number of deployed replicas is ready
check_replicas() {
    until kubectl get deploy $1 -o jsonpath='{.status.readyReplicas}' | grep $2; do
        echo "waiting for $1 to be ready"
        sleep 10
    done
}

# Get node IP
get_nodeIP() {
    kubectl get node $1 -o jsonpath='{.status.addresses[0].address}'
}

# Get the last digit of the node IP
get_nodeID() {
    get_nodeIP $1 | awk -F . '{print $4}'
}

# -----------------------End function-------------------------------------#

# -----------------------Start deploying zookeeper------------------------#

# Get zookeeper cluster node parameters
# eg: 192.168.1.11:2888:3888::11 192.168.1.12:2888:3888::12 192.168.1.13:2888:3888::13
zoo_servers=$(for node in ${zookeeper_node[@]}; do
    id=$(get_nodeID $node)
    ip=$(get_nodeIP $node)
    echo $ip:2888:3888::$id
done | tr '\n' ' ' | sed 's/ $//')

# zookeeper/zookeeper.yaml placeholder replacement and deployment
sed -e "s#replicas: 3#replicas: ${#zookeeper_node[@]}#g" \
    -e "s#Placeholder_registry#${registry}#g" \
    -e "s#Placeholder_zoo_servers#${zoo_servers}#g" \
    zookeeper/zookeeper.yaml | kubectl apply -f -

# Check zookeeper replicas is ready，If this operation fails, it will continue
check_replicas zookeeper ${#zookeeper_node[@]}

# -----------------------End the deployment of zookeeper-------------------#

# -----------------------Start deploying hadoop----------------------------#

# Get zookeeper cluster node parameters
# eg: 192.168.1.11:2181,192.168.1.12:2181,192.168.1.13:2181
zk_quorum=$(for node in ${zookeeper_node[@]}; do
    ip=$(get_nodeIP $node)
    echo $ip:2181
done | tr '\n' ',' | sed 's/,$//')

# Get journalnode cluster node parameters
# eg: 192.168.1.11:8485,192.168.1.12:8485,192.168.1.13:8485
qjournal=$(for node in ${journal_node[@]}; do
    ip=$(get_nodeIP $node)
    echo $ip:8485
done | tr '\n' ';' | sed 's/;$//')

# Get namenode node IPs
nn1_node_ip=$(get_nodeIP ${namenode1_node[0]})
nn2_node_ip=$(get_nodeIP ${namenode2_node[0]})

# Deploy hadoop configuration
sed -e "s#Placeholder_zk_quorum#${zk_quorum}#g" \
    -e "s#Placeholder_nn1_node#${nn1_node_ip}#g" \
    -e "s#Placeholder_nn2_node#${nn2_node_ip}#g" \
    -e "s#Placeholder_qjournal#${qjournal}#g" \
    -e "s#Placeholder_jobhistory#${nn1_node_ip}#g" \
    -e "s#Placeholder_rm1_node#${nn1_node_ip}#g" \
    -e "s#Placeholder_rm2_node#${nn2_node_ip}#g" \
    hadoop/hadoop-config.yaml | kubectl apply -f -

# Deploy hadoop journalnode
sed -e "s/replicas: 3/replicas: ${#journal_node[@]}/g" \
    -e "s#Placeholder_registry#${registry}#g" \
    hadoop/journalnode.yaml | kubectl apply -f -

# Check journalnode replicas and service is ready
check_replicas journalnode ${#journal_node[@]}
journal_node1_ip=$(get_nodeIP ${journal_node[0]})
check_service ${journal_node1_ip}:8480

# Deploy hadoop namenode1
sed "s#Placeholder_registry#${registry}#g" \
    hadoop/namenode1.yaml | kubectl apply -f -

# Check namenode1 service is ready
check_service ${nn1_node_ip}:9870

# Deploy hadoop resourcemanager1
sed "s#Placeholder_registry#${registry}#g" \
    hadoop/resourcemanager1.yaml | kubectl apply -f -

# Check resourcemanager1 service is ready
check_service ${nn1_node_ip}:8088

# Deploy hadoop historyserver
sed "s#Placeholder_registry#${registry}#g" \
    hadoop/historyserver.yaml | kubectl apply -f -

# Deploy hadoop namenode2 resourcemanager2
sed "s#Placeholder_registry#${registry}#g" \
    hadoop/namenode2.yaml | kubectl apply -f -

sed "s#Placeholder_registry#${registry}#g" \
    hadoop/resourcemanager2.yaml | kubectl apply -f -

# Deploy hadoop datanode and nodemanager
sed -e "s/replicas: 3/replicas: ${#datanode_node[@]}/g" \
    -e "s#Placeholder_registry#${registry}#g" \
    hadoop/datanode.yaml | kubectl apply -f -

sed -e "s/replicas: 3/replicas: ${#datanode_node[@]}/g" \
    -e "s#Placeholder_registry#${registry}#g" \
    hadoop/nodemanager.yaml | kubectl apply -f -

# Check datanode and nodemanager replicas is ready
check_replicas datanode ${#datanode_node[@]}
check_replicas nodemanager ${#datanode_node[@]}

# -----------------------Finish deploying hadoop---------------------------#

# -----------------------Start deploying hive------------------------------#
# Deploy hive configuration
hive_node_ip=$(get_nodeIP ${hive_node[0]})

sed -e "s#Placeholder_hive_node#${hive_node_ip}#g" \
    -e "s#Placeholder_hive_password#${hive_mysql_hive_password}#g" \
    hive/hive-config.yaml | kubectl apply -f -

# Deploy hive mysql
sed -e "s#Placeholder_registry#${registry}#g" \
    -e "s#Placeholder_root_password#${hive_mysql_root_password}#g" \
    -e "s#Placeholder_hive_password#${hive_mysql_hive_password}#g" \
    hive/hive-mysql.yaml | kubectl apply -f -

# Check hive mysql service is ready
check_service ${hive_node_ip}:3306

# Deploy hive metastore
sed "s#Placeholder_registry#${registry}#g" \
    hive/hive-metastore.yaml | kubectl apply -f -

# Check metastore service is ready
check_replicas hive-metastore ${#hive_node[@]}

# -----------------------Finish deploying hive-----------------------------#

# -----------------------start deploying spark-----------------------------#

# Deploy spark configuration
spark_node_ip=$(get_nodeIP ${spark_node[0]})

sed -e "s#Placeholder_nn1_node#${nn1_node_ip}#g" \
    -e "s#Placeholder_spark_history_node#${spark_node_ip}#g" \
    spark/spark-config.yaml | kubectl apply -f -

# Deploy spark
sed -e "s#Placeholder_registry#${registry}#g" \
    spark/spark.yaml | kubectl apply -f -

# Deploy spark-historyserver
sed -e "s#Placeholder_registry#${registry}#g" \
    spark/spark-historyserver.yaml | kubectl apply -f -

# Check historyserver service is ready
check_service ${spark_node_ip}:18080

# -----------------------Finish deploying spark-----------------------------#

# -----------------------Start deploying trino------------------------------#

# Deploy trino configuration
trino_master_node_ip=$(get_nodeIP ${trino_master_node[0]})

sed -e "s#Placeholder_trino_master_node#${trino_master_node_ip}#g" \
    -e "s#Placeholder_hive_node#${hive_node_ip}#g" \
    trino/trino-config.yaml | kubectl apply -f -

# Deploy trino master
sed -e "s#Placeholder_registry#${registry}#g" \
    trino/trino-master.yaml | kubectl apply -f -

# Check trino master service is ready
check_service ${trino_master_node_ip}:8082

# Deploy trino worker
sed -e "s#Placeholder_registry#${registry}#g" \
    trino/trino-worker.yaml | kubectl apply -f -

# -----------------------Finish deploying trino------------------------------#

# -----------------------Start deploying kafka-------------------------------#

# Deploy kafka
sed -e "s#Placeholder_registry#${registry}#g" \
    -e "s#Placeholder_zk_quorum#${zk_quorum}#g" \
    kafka/kafka.yaml | kubectl apply -f -

# Check kafka replicas is ready
check_replicas kafka ${#kafka_node[@]}

# -----------------------Finish deploying kafka-------------------------------#

# -----------------------Start deploying clickhouse---------------------------#

# Deploy clickhouse configuration
clickhouse_node1_ip=$(get_nodeIP ${clickhouse_node[0]})
clickhouse_node2_ip=$(get_nodeIP ${clickhouse_node[1]})
clickhouse_node3_ip=$(get_nodeIP ${clickhouse_node[2]})
clickhouse_node4_ip=$(get_nodeIP ${clickhouse_node[3]})
zk_node1_ip=$(get_nodeIP ${zk_node[0]})
zk_node2_ip=$(get_nodeIP ${zk_node[1]})
zk_node3_ip=$(get_nodeIP ${zk_node[2]})

sed -e "s#Placeholder_zk1_node#${zk_node1_ip}#g" \
    -e "s#Placeholder_zk2_node#${zk_node1_ip}#g" \
    -e "s#Placeholder_zk3_node#${zk_node1_ip}#g" \
    -e "s#Placeholder_clickhouse1_node#${clickhouse_node1_ip}#g" \
    -e "s#Placeholder_clickhouse2_node#${clickhouse_node2_ip}#g" \
    -e "s#Placeholder_clickhouse3_node#${clickhouse_node3_ip}#g" \
    -e "s#Placeholder_clickhouse4_node#${clickhouse_node4_ip}#g" \
    clickhouse/clickhouse-config.yaml | kubectl apply -f -

# Deploy clickhouse server
sed -e "s#Placeholder_registry#${registry}#g" \
    clickhouse/clickhouse-server.yaml | kubectl apply -f -

# Check clickhouse server service is ready
check_replicas clickhouse ${#clickhouse_node[@]}

# -----------------------Finish deploying clickhouse---------------------------#
