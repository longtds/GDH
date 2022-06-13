# GDH
Running big data components on kubernetes

## Required  
1. kubernetes cluster v1.18+
2. kubectl with cluster admin role on linux

## Config  
1. Planning Nodes for Service Deployment, eg:  
    namespace: bigdata  

    | node | services |
    | --- | --- |
    | node1 | nn1 rm1 dn nm |
    | node2 | nn2 rm2 dn nm |
    | node3 | zk dn nm kafka |
    | node4 | zk dn nm kafka |
    | node5 | zk dn nm kafka |

2. Modify the configuration file config.sh to suit your plan

## Deploy
```bash
./installl.sh
```

## Service default port
| service | ports |
| --- | --- |
| zookeeper | 2181 |
| journalnode | 8485 8480 |
| namenode | 8020 9870 |
| resourcemanager | 8088 |
| histroyserver | 10020 19888 |
| hive | 9083 10000 10002 |
| spark | 12222 10000 |
| trino | 8082 |
| clickhouse | 8123 |
| kafka | 9092 |

## Known Issues
1. namenode failover not implemented