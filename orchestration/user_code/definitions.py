"""
Dagster definitions for Agartha data platform.

This is the main entry point for Dagster, defining all assets,
resources, jobs, and schedules for the platform.
"""

import os
from typing import Optional

from dagster import (
    AssetExecutionContext,
    AssetSelection,
    ConfigurableResource,
    Definitions,
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

class NessieIcebergResource(ConfigurableResource):
    """Resource for interacting with Iceberg tables via Nessie catalog."""

    nessie_uri: str = Field(
        default_factory=lambda: os.environ.get(
            "NESSIE_URI", "http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2"
        ),
        description="Nessie REST API endpoint",
    )
    nessie_ref: str = Field(
        default_factory=lambda: os.environ.get("NESSIE_REF", "main"),
        description="Nessie branch or tag reference",
    )
    warehouse: str = Field(
        default_factory=lambda: os.environ.get("S3_WAREHOUSE", "s3a://agartha-warehouse/"),
        description="S3 warehouse location for Iceberg tables",
    )
    s3_endpoint: str = Field(
        default_factory=lambda: os.environ.get(
            "S3_ENDPOINT", "http://minio.agartha-storage.svc.cluster.local:9000"
        ),
        description="S3 endpoint URL",
    )
    s3_access_key: str = Field(
        default_factory=lambda: os.environ.get("S3_ACCESS_KEY_ID", ""),
        description="S3 access key",
    )
    s3_secret_key: str = Field(
        default_factory=lambda: os.environ.get("S3_SECRET_ACCESS_KEY", ""),
        description="S3 secret key",
    )

    def get_spark_session(self):
        """Create a SparkSession configured for Iceberg with Nessie catalog."""
        from pyspark.sql import SparkSession

        spark = (
            SparkSession.builder.appName("dagster-agartha")
            .config(
                "spark.jars.packages",
                "org.apache.iceberg:iceberg-spark-runtime-3.3_2.12:1.5.0,"
                "org.projectnessie.nessie-integrations:nessie-spark-extensions-3.3_2.12:0.79.0,"
                "software.amazon.awssdk:bundle:2.17.178,"
                "software.amazon.awssdk:url-connection-client:2.17.178",
            )
            .config(
                "spark.sql.extensions",
                "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,"
                "org.projectnessie.spark.extensions.NessieSparkSessionExtensions",
            )
            .config("spark.sql.catalog.agartha", "org.apache.iceberg.spark.SparkCatalog")
            .config(
                "spark.sql.catalog.agartha.catalog-impl",
                "org.apache.iceberg.nessie.NessieCatalog",
            )
            .config("spark.sql.catalog.agartha.uri", self.nessie_uri)
            .config("spark.sql.catalog.agartha.ref", self.nessie_ref)
            .config("spark.sql.catalog.agartha.warehouse", self.warehouse)
            .config("spark.hadoop.fs.s3a.endpoint", self.s3_endpoint)
            .config("spark.hadoop.fs.s3a.access.key", self.s3_access_key)
            .config("spark.hadoop.fs.s3a.secret.key", self.s3_secret_key)
            .config("spark.hadoop.fs.s3a.path.style.access", "true")
            .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
            .getOrCreate()
        )
        return spark


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
        default_factory=lambda: os.environ.get("SPARK_IMAGE", "openlake/spark-py:3.3.2"),
        description="Spark container image",
    )

    def create_spark_application_manifest(
        self,
        name: str,
        main_application_file: str,
        arguments: Optional[list[str]] = None,
    ) -> dict:
        """Generate a SparkApplication custom resource manifest."""
        return {
            "apiVersion": "sparkoperator.k8s.io/v1beta2",
            "kind": "SparkApplication",
            "metadata": {"name": name, "namespace": self.namespace},
            "spec": {
                "type": "Python",
                "pythonVersion": "3",
                "mode": "cluster",
                "image": self.image,
                "mainApplicationFile": main_application_file,
                "arguments": arguments or [],
                "sparkVersion": "3.3.2",
                "driver": {
                    "cores": 1,
                    "memory": "1g",
                    "serviceAccount": self.service_account,
                },
                "executor": {"cores": 1, "instances": 1, "memory": "1g"},
            },
        }


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
    nessie_iceberg: NessieIcebergResource,
) -> MaterializeResult:
    """
    Ingest raw people data from S3 text files into an Iceberg table.
    """
    spark = nessie_iceberg.get_spark_session()
    try:
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.raw")
        raw_df = spark.read.text("s3a://agartha-raw/people.txt")

        from pyspark.sql.functions import col, split, trim

        parsed_df = raw_df.select(
            trim(split(col("value"), "\\|").getItem(0)).alias("first_name"),
            trim(split(col("value"), "\\|").getItem(1)).alias("last_name"),
            trim(split(col("value"), "\\|").getItem(2)).cast("int").alias("age"),
        )
        parsed_df.writeTo("agartha.raw.people").createOrReplace()
        row_count = parsed_df.count()
        context.log.info(f"Wrote {row_count} rows to agartha.raw.people")

        return MaterializeResult(
            metadata={
                "row_count": MetadataValue.int(row_count),
                "table": MetadataValue.text("agartha.raw.people"),
            }
        )
    finally:
        spark.stop()


@asset(
    group_name="curated",
    description="Curated people data with validation and cleaning applied",
    deps=[raw_people],
    compute_kind="spark",
)
def curated_people(
    context: AssetExecutionContext,
    nessie_iceberg: NessieIcebergResource,
) -> MaterializeResult:
    """
    Clean and validate people data from raw layer.
    """
    spark = nessie_iceberg.get_spark_session()
    try:
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.curated")
        raw_df = spark.table("agartha.raw.people")

        from pyspark.sql.functions import col, initcap

        curated_df = (
            raw_df.filter(col("first_name").isNotNull())
            .filter(col("last_name").isNotNull())
            .filter((col("age") >= 0) & (col("age") <= 120))
            .withColumn("first_name", initcap(col("first_name")))
            .withColumn("last_name", initcap(col("last_name")))
        )
        curated_df.writeTo("agartha.curated.people").createOrReplace()

        raw_count = raw_df.count()
        curated_count = curated_df.count()
        context.log.info(f"Curated {curated_count} rows (filtered {raw_count - curated_count})")

        return MaterializeResult(
            metadata={
                "row_count": MetadataValue.int(curated_count),
                "filtered_count": MetadataValue.int(raw_count - curated_count),
            }
        )
    finally:
        spark.stop()


@asset(
    group_name="analytics",
    description="Age distribution analytics aggregation",
    deps=[curated_people],
    compute_kind="spark",
)
def people_age_distribution(
    context: AssetExecutionContext,
    nessie_iceberg: NessieIcebergResource,
) -> MaterializeResult:
    """
    Compute age distribution statistics from curated people data.
    """
    spark = nessie_iceberg.get_spark_session()
    try:
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.analytics")
        curated_df = spark.table("agartha.curated.people")

        from pyspark.sql.functions import col, count, when

        age_dist_df = curated_df.select(
            when(col("age") < 18, "0-17")
            .when(col("age") < 30, "18-29")
            .when(col("age") < 45, "30-44")
            .when(col("age") < 60, "45-59")
            .otherwise("60+")
            .alias("age_group")
        ).groupBy("age_group").agg(count("*").alias("count"))

        age_dist_df.writeTo("agartha.analytics.people_age_distribution").createOrReplace()
        context.log.info(f"Created age distribution with {age_dist_df.count()} buckets")

        return MaterializeResult(
            metadata={"bucket_count": MetadataValue.int(age_dist_df.count())}
        )
    finally:
        spark.stop()


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
        "nessie_iceberg": NessieIcebergResource(),
        "spark_operator": SparkOperatorResource(),
    },
    jobs=[people_pipeline_job, raw_ingestion_job],
    schedules=[daily_pipeline_schedule],
)
