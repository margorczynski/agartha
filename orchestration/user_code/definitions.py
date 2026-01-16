"""
Dagster definitions for Agartha data platform.

This module defines assets that orchestrate Spark jobs via the Kubernetes
Spark Operator. Dagster handles orchestration while Spark Operator manages
the actual Spark job execution.
"""

import os
import time
import uuid
from typing import Any

from dagster import (
    AssetExecutionContext,
    AssetSelection,
    ConfigurableResource,
    Definitions,
    Failure,
    MaterializeResult,
    MetadataValue,
    ScheduleDefinition,
    asset,
    define_asset_job,
)
from pydantic import Field


# ============================================================================
# Resources
# ============================================================================


class SparkOperatorResource(ConfigurableResource):
    """Resource for submitting Spark applications via Kubernetes Spark Operator."""

    namespace: str = Field(
        default_factory=lambda: os.environ.get("SPARK_NAMESPACE", "agartha-processing-spark"),
        description="Kubernetes namespace for Spark operator",
    )
    service_account: str = Field(
        default_factory=lambda: os.environ.get("SPARK_SERVICE_ACCOUNT", "spark-sa"),
        description="Service account for Spark pods",
    )
    image: str = Field(
        default_factory=lambda: os.environ.get("SPARK_IMAGE", "apache/spark:3.5.0-python3"),
        description="Spark container image",
    )
    scripts_config_map: str = Field(
        default="dagster-spark-scripts",
        description="ConfigMap containing PySpark scripts",
    )
    scripts_mount_path: str = Field(
        default="/opt/spark/scripts",
        description="Mount path for scripts in Spark pods",
    )
    nessie_uri: str = Field(
        default_factory=lambda: os.environ.get(
            "NESSIE_URI", "http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2"
        ),
    )
    s3_endpoint: str = Field(
        default_factory=lambda: os.environ.get(
            "S3_ENDPOINT", "http://minio.agartha-storage.svc.cluster.local:9000"
        ),
    )
    s3_warehouse: str = Field(
        default_factory=lambda: os.environ.get("S3_WAREHOUSE", "s3a://agartha-warehouse/"),
    )
    s3_access_key: str = Field(
        default_factory=lambda: os.environ.get("S3_ACCESS_KEY_ID", ""),
    )
    s3_secret_key: str = Field(
        default_factory=lambda: os.environ.get("S3_SECRET_ACCESS_KEY", ""),
    )
    poll_interval: int = Field(default=5, description="Seconds between status polls")
    timeout: int = Field(default=600, description="Max seconds to wait for job completion")

    def submit_and_wait(
        self,
        context: AssetExecutionContext,
        script_name: str,
    ) -> dict[str, Any]:
        """
        Submit a Spark job and wait for completion.

        Args:
            context: Dagster execution context for logging
            script_name: Name of the script file (e.g., "raw_people.py")

        Returns:
            Dict with job status and metadata

        Raises:
            Failure: If job fails or times out
        """
        from kubernetes import client, config

        # Load in-cluster config (running inside K8s)
        try:
            config.load_incluster_config()
        except config.ConfigException:
            # Fallback for local development
            config.load_kube_config()

        api = client.CustomObjectsApi()

        # Generate unique job name
        job_id = str(uuid.uuid4())[:8]
        job_name = f"dagster-{script_name.replace('.py', '').replace('_', '-')}-{job_id}"

        # Create SparkApplication manifest
        spark_app = self._create_spark_application(job_name, script_name)

        context.log.info(f"Submitting SparkApplication: {job_name}")

        # Submit the SparkApplication
        api.create_namespaced_custom_object(
            group="sparkoperator.k8s.io",
            version="v1beta2",
            namespace=self.namespace,
            plural="sparkapplications",
            body=spark_app,
        )

        # Poll for completion
        start_time = time.time()
        while True:
            elapsed = time.time() - start_time
            if elapsed > self.timeout:
                self._cleanup_job(api, job_name)
                raise Failure(
                    description=f"Spark job {job_name} timed out after {self.timeout}s"
                )

            status = self._get_job_status(api, job_name)
            state = status.get("applicationState", {}).get("state", "UNKNOWN")

            context.log.info(f"Spark job {job_name} state: {state} (elapsed: {int(elapsed)}s)")

            if state == "COMPLETED":
                context.log.info(f"Spark job {job_name} completed successfully")
                self._cleanup_job(api, job_name)
                return {"status": "success", "job_name": job_name}

            if state in ("FAILED", "SUBMISSION_FAILED"):
                error_msg = status.get("applicationState", {}).get("errorMessage", "Unknown error")
                self._cleanup_job(api, job_name)
                raise Failure(description=f"Spark job {job_name} failed: {error_msg}")

            time.sleep(self.poll_interval)

    def _create_spark_application(self, job_name: str, script_name: str) -> dict:
        """Generate SparkApplication custom resource manifest."""
        return {
            "apiVersion": "sparkoperator.k8s.io/v1beta2",
            "kind": "SparkApplication",
            "metadata": {
                "name": job_name,
                "namespace": self.namespace,
            },
            "spec": {
                "type": "Python",
                "pythonVersion": "3",
                "mode": "cluster",
                "image": self.image,
                "imagePullPolicy": "IfNotPresent",
                "mainApplicationFile": f"local://{self.scripts_mount_path}/{script_name}",
                "sparkVersion": "3.5.0",
                "restartPolicy": {"type": "Never"},
                "sparkConf": {
                    # Iceberg and Nessie configuration
                    "spark.sql.extensions": (
                        "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,"
                        "org.projectnessie.spark.extensions.NessieSparkSessionExtensions"
                    ),
                    "spark.sql.catalog.agartha": "org.apache.iceberg.spark.SparkCatalog",
                    "spark.sql.catalog.agartha.catalog-impl": "org.apache.iceberg.nessie.NessieCatalog",
                    "spark.sql.catalog.agartha.uri": self.nessie_uri,
                    "spark.sql.catalog.agartha.ref": "main",
                    "spark.sql.catalog.agartha.warehouse": self.s3_warehouse,
                    # S3/MinIO configuration
                    "spark.hadoop.fs.s3a.endpoint": self.s3_endpoint,
                    "spark.hadoop.fs.s3a.access.key": self.s3_access_key,
                    "spark.hadoop.fs.s3a.secret.key": self.s3_secret_key,
                    "spark.hadoop.fs.s3a.path.style.access": "true",
                    "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem",
                    "spark.hadoop.fs.s3a.connection.ssl.enabled": "false",
                },
                "deps": {
                    "jars": [],
                    "packages": [
                        "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.0",
                        "org.projectnessie.nessie-integrations:nessie-spark-extensions-3.5_2.12:0.79.0",
                        "software.amazon.awssdk:bundle:2.24.8",
                        "software.amazon.awssdk:url-connection-client:2.24.8",
                    ],
                },
                "driver": {
                    "cores": 1,
                    "coreLimit": "1200m",
                    "memory": "1g",
                    "labels": {"version": "3.5.0"},
                    "serviceAccount": self.service_account,
                    "volumeMounts": [
                        {
                            "name": "spark-scripts",
                            "mountPath": self.scripts_mount_path,
                        }
                    ],
                    "env": [
                        {"name": "NESSIE_URI", "value": self.nessie_uri},
                        {"name": "S3_ENDPOINT", "value": self.s3_endpoint},
                        {"name": "S3_WAREHOUSE", "value": self.s3_warehouse},
                        {"name": "S3_ACCESS_KEY_ID", "value": self.s3_access_key},
                        {"name": "S3_SECRET_ACCESS_KEY", "value": self.s3_secret_key},
                    ],
                },
                "executor": {
                    "cores": 1,
                    "instances": 1,
                    "memory": "1g",
                    "labels": {"version": "3.5.0"},
                    "volumeMounts": [
                        {
                            "name": "spark-scripts",
                            "mountPath": self.scripts_mount_path,
                        }
                    ],
                    "env": [
                        {"name": "NESSIE_URI", "value": self.nessie_uri},
                        {"name": "S3_ENDPOINT", "value": self.s3_endpoint},
                        {"name": "S3_WAREHOUSE", "value": self.s3_warehouse},
                        {"name": "S3_ACCESS_KEY_ID", "value": self.s3_access_key},
                        {"name": "S3_SECRET_ACCESS_KEY", "value": self.s3_secret_key},
                    ],
                },
                "volumes": [
                    {
                        "name": "spark-scripts",
                        "configMap": {"name": self.scripts_config_map},
                    }
                ],
            },
        }

    def _get_job_status(self, api: Any, job_name: str) -> dict:
        """Get the status of a SparkApplication."""
        try:
            result = api.get_namespaced_custom_object(
                group="sparkoperator.k8s.io",
                version="v1beta2",
                namespace=self.namespace,
                plural="sparkapplications",
                name=job_name,
            )
            return result.get("status", {})
        except Exception:
            return {}

    def _cleanup_job(self, api: Any, job_name: str) -> None:
        """Delete the SparkApplication after completion."""
        try:
            api.delete_namespaced_custom_object(
                group="sparkoperator.k8s.io",
                version="v1beta2",
                namespace=self.namespace,
                plural="sparkapplications",
                name=job_name,
            )
        except Exception:
            pass  # Ignore cleanup errors


# ============================================================================
# Assets
# ============================================================================


@asset(
    group_name="raw",
    description="Raw people data ingested from source files into Iceberg table",
    compute_kind="spark",
)
def raw_people(
    context: AssetExecutionContext,
    spark_operator: SparkOperatorResource,
) -> MaterializeResult:
    """
    Ingest raw people data from S3 text files into an Iceberg table.
    Submits a Spark job via Spark Operator.
    """
    result = spark_operator.submit_and_wait(context, "raw_people.py")

    return MaterializeResult(
        metadata={
            "spark_job": MetadataValue.text(result["job_name"]),
            "table": MetadataValue.text("agartha.raw.people"),
        }
    )


@asset(
    group_name="curated",
    description="Curated people data with validation and cleaning applied",
    deps=[raw_people],
    compute_kind="spark",
)
def curated_people(
    context: AssetExecutionContext,
    spark_operator: SparkOperatorResource,
) -> MaterializeResult:
    """
    Clean and validate people data from raw layer.
    Submits a Spark job via Spark Operator.
    """
    result = spark_operator.submit_and_wait(context, "curated_people.py")

    return MaterializeResult(
        metadata={
            "spark_job": MetadataValue.text(result["job_name"]),
            "table": MetadataValue.text("agartha.curated.people"),
        }
    )


@asset(
    group_name="analytics",
    description="Age distribution analytics aggregation",
    deps=[curated_people],
    compute_kind="spark",
)
def people_age_distribution(
    context: AssetExecutionContext,
    spark_operator: SparkOperatorResource,
) -> MaterializeResult:
    """
    Compute age distribution statistics from curated people data.
    Submits a Spark job via Spark Operator.
    """
    result = spark_operator.submit_and_wait(context, "people_age_distribution.py")

    return MaterializeResult(
        metadata={
            "spark_job": MetadataValue.text(result["job_name"]),
            "table": MetadataValue.text("agartha.analytics.people_age_distribution"),
        }
    )


# ============================================================================
# Jobs and Schedules
# ============================================================================

people_pipeline_job = define_asset_job(
    name="people_pipeline",
    description="Full ETL pipeline for people data: raw -> curated -> analytics",
    selection=AssetSelection.groups("raw", "curated", "analytics"),
)

raw_ingestion_job = define_asset_job(
    name="raw_ingestion",
    description="Ingest raw data from source files",
    selection=AssetSelection.groups("raw"),
)

daily_pipeline_schedule = ScheduleDefinition(
    name="daily_people_pipeline",
    job=people_pipeline_job,
    cron_schedule="0 2 * * *",
    description="Daily full ETL pipeline for people data",
)


# ============================================================================
# Definitions
# ============================================================================

defs = Definitions(
    assets=[raw_people, curated_people, people_age_distribution],
    resources={
        "spark_operator": SparkOperatorResource(),
    },
    jobs=[people_pipeline_job, raw_ingestion_job],
    schedules=[daily_pipeline_schedule],
)
