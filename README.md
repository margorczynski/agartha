minikube delete && minikube start && minikube addons enable ingress &&  minikube dashboard

tofu init

tofu apply

|Module|Description|Component|
|:-|:-: |:-:|
|storage | Data & metadata storage | MinIO, maybe switch to Garage|
|catalog | Data catalog and table metadata | Nessie|
|processing | Processing data (batches and streams) | Spark, Trino, Flink| 
|business_intelligence| Data visualization, dashboards and BI| Superset|
|workflows| Workflow management and scheduling| Airflow|
|monitoring| Monitoring and alerts |Grafana|
|identity| Identity and access management | Keycloak| 
|notebooks| Notebooks for interactive processing & querying | JupyterHub|
