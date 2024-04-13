# Agartha

### Terraform/OpenTofu modules, components and k8s namespaces summary
|TF Module|Description|Components|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|
|storage | Data & metadata storage | MinIO, maybe switch to Garage|agartha-storage|
|catalog | Data catalog and table metadata | Nessie|agartha-catalog|
|processing | Processing data (batches and streams) | Spark, Trino, Flink|agartha-processing-[spark/flink/trino]|
|notebooks| Notebooks for interactive processing | JupyterHub|agartha-notebooks|
|business_intelligence| Data visualization, dashboards and BI| Superset|agartha-bi|
|orchestration| Workflow management and scheduling| Airflow|agartha-orchestration|
|monitoring| Logging, monitoring and alerts |Grafana, Prometheus|agartha-monitoring-[grafana/prometheus]|
|identity| Identity and access management |Keycloak| agartha-identity|

### Storage module details
|Component|Subcomponent|Description|Endpoint|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|:-:|
|MinIO|MinIO Operator Console|Operator console of MinIO used for managing and provisioning tenants|minio-operator-console.agartha.*|agartha-storage|
|MinIO|MinIO Tenant Console|Tenant console of MinIO used for managing the tenant|minio-tenant-console.agartha.*|agartha-storage|
|MinIO|MinIO Server|Tenant server and S3 endpoint|minio.agartha.*|agartha-storage|

### Catalog module details
|Component|Subcomponent|Description|Endpoint|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|:-:|
|Nessie||Catalog for metadata tracking|nessie.agartha.*|agartha-catalog|

### Processing module details
|Component|Subcomponent|Description|Endpoint|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|:-:|
|Spark||Batch processing engine|trino.agartha.*|agartha-processing-spark|
|Flink||Streaming processing engine|trino.agartha.*|agartha-processing-flink|
|Trino||SQL query engine|trino.agartha.*|agartha-processing-trino|

# Deployment and testing

## Post-deployment setup

* MinIO
    * Enable versioning - can rewind lost data
    * Enable encryption
    * Enable replication

## Testing with Minikube

### Prerequisites

* Minikube installed
* OpenTofu installed

### Start minikube

```
minikube delete
minikube config set cpus 8
minikube config set memory 16384
minikube start && minikube addons enable ingress &&  minikube dashboard
```

### Clone the repository and execute the Terraform plan
```bash
git clone https://github.com/margorczynski/agartha.git
cd agartha
tofu init
tofu apply -auto-approve
```

### Add local routing
To make the endpoints accessible we need to setup some customer routing that will redirect us to the minikube IP address. 

This can be done via the following commands:
```bash
AGARTHA_HOST=minikubehost.com
MINIKUBE_IP=$(minikube ip)

echo minio-operator-console,minio-tenant-console,minio,nessie,trino,spark,flink | \
 tr ',' '\n' | \
 xargs -I {} echo ${MINIKUBE_IP} {}.agartha.${AGARTHA_HOST} | \
 sudo tee -a /etc/hosts
```