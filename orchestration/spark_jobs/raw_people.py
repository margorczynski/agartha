"""
Spark job: Ingest raw people data from S3 text files into Iceberg table.

This job is submitted via Spark Operator and orchestrated by Dagster.
"""

import sys
from pyspark.sql import SparkSession
from pyspark.sql.functions import col, split, trim


def main():
    spark = create_spark_session()
    try:
        # Create namespace if not exists
        spark.sql("CREATE NAMESPACE IF NOT EXISTS agartha.raw")

        # Read raw text file
        raw_df = spark.read.text("s3a://agartha-raw/people.txt")

        # Parse pipe-delimited data
        parsed_df = raw_df.select(
            trim(split(col("value"), "\\|").getItem(0)).alias("first_name"),
            trim(split(col("value"), "\\|").getItem(1)).alias("last_name"),
            trim(split(col("value"), "\\|").getItem(2)).cast("int").alias("age"),
        )

        # Write to Iceberg table
        parsed_df.writeTo("agartha.raw.people").createOrReplace()

        row_count = parsed_df.count()
        print(f"SUCCESS: Wrote {row_count} rows to agartha.raw.people")

    except Exception as e:
        print(f"ERROR: {e}", file=sys.stderr)
        sys.exit(1)
    finally:
        spark.stop()


def create_spark_session() -> SparkSession:
    """Create SparkSession configured for Iceberg with Nessie catalog."""
    import os

    nessie_uri = os.environ.get(
        "NESSIE_URI", "http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2"
    )
    nessie_ref = os.environ.get("NESSIE_REF", "main")
    warehouse = os.environ.get("S3_WAREHOUSE", "s3a://agartha-warehouse/")
    s3_endpoint = os.environ.get(
        "S3_ENDPOINT", "http://minio.agartha-storage.svc.cluster.local:9000"
    )
    s3_access_key = os.environ.get("S3_ACCESS_KEY_ID", "")
    s3_secret_key = os.environ.get("S3_SECRET_ACCESS_KEY", "")

    return (
        SparkSession.builder.appName("raw_people")
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
        .config("spark.sql.catalog.agartha.uri", nessie_uri)
        .config("spark.sql.catalog.agartha.ref", nessie_ref)
        .config("spark.sql.catalog.agartha.warehouse", warehouse)
        .config("spark.hadoop.fs.s3a.endpoint", s3_endpoint)
        .config("spark.hadoop.fs.s3a.access.key", s3_access_key)
        .config("spark.hadoop.fs.s3a.secret.key", s3_secret_key)
        .config("spark.hadoop.fs.s3a.path.style.access", "true")
        .config("spark.hadoop.fs.s3a.impl", "org.apache.hadoop.fs.s3a.S3AFileSystem")
        .getOrCreate()
    )


if __name__ == "__main__":
    main()
