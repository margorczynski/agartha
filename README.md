# Agartha

## Terraform/OpenTofu modules, components and k8s namespaces summary
|TF Module|Description|Components|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|
|storage | Data & metadata storage | MinIO, maybe switch to Garage|agartha-storage|
|catalog | Data catalog and table metadata | Nessie|agartha-catalog|
|processing | Processing data (batches and streams) | Spark, Trino, Flink|agartha-processing-[spark/flink/trino]|
|notebooks| Notebooks for interactive processing | JupyterHub|agartha-notebooks|
|bi| Data visualization, dashboards and BI| Superset|agartha-bi|
|orchestration| Workflow management and scheduling| Dagster|agartha-orchestration|
|monitoring| Logging, monitoring and alerts |Grafana, Prometheus, Loki, Alertmanager|agartha-monitoring|
|identity| Identity and access management |Keycloak| agartha-identity|

## Storage
|Component|Subcomponent|Description|Endpoint|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|:-:|
|MinIO|MinIO Operator Console|Operator console of MinIO used for managing and provisioning tenants|minio-operator-console.agartha.*|agartha-storage|
|MinIO|MinIO Tenant Console|Tenant console of MinIO used for managing the tenant|minio-tenant-console.agartha.*|agartha-storage|
|MinIO|MinIO Server|Tenant server and S3 endpoint|minio.agartha.*|agartha-storage|

## Catalog
|Component|Subcomponent|Description|Endpoint|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|:-:|
|Nessie||Catalog for metadata tracking|nessie.agartha.*|agartha-catalog|

## Processing
|Component|Subcomponent|Description|Endpoint|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|:-:|
|Spark||Batch processing engine|spark.agartha.*/SPARK_APP_NAME|agartha-processing-spark|
|Flink||Streaming processing engine|flink.agartha.*/FLINK_APP_NAME|agartha-processing-flink|
|Trino||SQL query engine|trino.agartha.*|agartha-processing-trino|

## BI
|Component|Subcomponent|Description|Endpoint|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|:-:|
|Superset||Data exploration and visualization|superset.agartha.*|agartha-bi|

## Monitoring
|Component|Subcomponent|Description|Endpoint|Kubernetes Namespace|
|:-:|:-:|:-:|:-:|:-:|
|Grafana||Metrics visualization and dashboards|grafana.agartha.*|agartha-monitoring|
|Prometheus||Metrics collection and storage|prometheus.agartha.*|agartha-monitoring|
|Alertmanager||Alert management and routing|alertmanager.agartha.*|agartha-monitoring|
|Loki||Log aggregation and querying|Internal only|agartha-monitoring|

### Pre-configured Dashboards
- **Agartha Data Platform Overview** - High-level view of all platform components
- **MinIO Storage** - Storage utilization, traffic, and S3 operations
- **Trino Query Engine** - Query performance, worker status, and resource usage
- **Spark Batch Processing** - Application status, executor metrics, and resource consumption
- **Flink Stream Processing** - Job manager/task manager status and streaming metrics

### Alert Rules
The monitoring stack includes pre-configured alerts for:
- Component availability (MinIO, Nessie, Trino, Spark Operator, Flink Operator)
- Storage utilization warnings (80%) and critical alerts (95%)
- High memory/CPU usage detection
- Pod crash looping and readiness issues
- Trino query queue and failure rate monitoring

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

### Upload example Dagster pipelines

After `tofu apply` completes, the Dagster user code deployment starts with an empty placeholder. To load the example GitHub ETL pipelines (dlt ingestion + Spark processing into Iceberg tables):

1. **Set up MinIO client** (port-forward and configure alias):
```bash
kubectl port-forward -n agartha-storage svc/minio 9000:80 &
S3_ACCESS_KEY=$(kubectl get secret -n agartha-orchestration dagster-s3-credentials \
  -o jsonpath='{.data.S3_ACCESS_KEY_ID}' | base64 -d)
S3_SECRET_KEY=$(kubectl get secret -n agartha-orchestration dagster-s3-credentials \
  -o jsonpath='{.data.S3_SECRET_ACCESS_KEY}' | base64 -d)
mc alias set local http://127.0.0.1:9000 "$S3_ACCESS_KEY" "$S3_SECRET_KEY"
```

2. **Upload the example code** (includes `requirements.txt` for pip dependencies):
```bash
mc cp --recursive examples/dagster/ local/agartha-dagster-code/agartha-pipelines/
```

3. **Restart the user code pod** to pick up the new code:
```bash
kubectl rollout restart deployment dagster-agartha-pipelines -n agartha-orchestration
```

The assets should appear in the Dagster UI at `dagster.agartha.<your-host>` after the pod becomes ready (this takes a couple of minutes as it installs pip dependencies on startup).

### Add local routing
To make the endpoints accessible we need to setup some customer routing that will redirect us to the minikube IP address. 

This can be done via the following commands:
```bash
AGARTHA_HOST=minikubehost.com
MINIKUBE_IP=$(minikube ip)

echo minio-operator-console,minio-tenant-console,minio,nessie,trino,spark,flink,superset,grafana,prometheus,alertmanager,keycloak | \
 tr ',' '\n' | \
 xargs -I {} echo ${MINIKUBE_IP} {}.agartha.${AGARTHA_HOST} | \
 sudo tee -a /etc/hosts
```
