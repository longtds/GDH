#!/bin/bash

# Mirror warehouse address, which can be used directly with public network environment
registry=registry.cn-beijing.aliyuncs.com/jtyj

# Deployment namespace
bigdata_namespace=bigdata

# Component node allocation, you can view the node name through "kubectl get node"
# zookeeper node selector，3 nodes recommended
zookeeper_node=(node3 node4 node5)

# hadoop node selector
namenode1_node=(node1)
namenode2_node=(node2)
datanode_node=(node1 node2 node3 node4 node5)
journal_node=(node3 node4 node5)

# hive node selector
hive_node=(node1)

# spark node selector
spark_node=(node2)

# kafka node selector
kafka_node=(node1 node2 node3)

# trino node selector
trino_master_node=(node5)
trino_worker_node=(node1 node2)

# clickhouse node selector，Currently only supports 4 nodes
clickhouse_node=(node2 node3 node4 node5)

# Password configuration
hive_mysql_root_password=hive@2022
hive_mysql_hive_password=hive@2022
