"""
Dagster resource for dlt integration.

This module provides a ConfigurableResource that wraps dlt pipelines
for use with Dagster assets. It handles:
- S3/MinIO destination configuration
- Pipeline state management
- Credential handling from environment variables
"""

import os

import dlt
from dagster import ConfigurableResource
from pydantic import Field


class DltPipelineResource(ConfigurableResource):
    """
    Dagster resource for running dlt pipelines with S3/MinIO destination.

    This resource configures dlt to write Parquet files to S3-compatible storage,
    which can then be queried via Trino or loaded into Iceberg tables.
    """

    s3_bucket: str = Field(
        default_factory=lambda: os.environ.get("DLT_S3_BUCKET", "agartha-raw"),
        description="S3 bucket for dlt output",
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
    pipeline_data_dir: str = Field(
        default="/tmp/dlt_pipelines",
        description="Local directory for dlt pipeline state and staging",
    )

    def create_pipeline(
        self,
        pipeline_name: str,
        dataset_name: str,
    ) -> dlt.Pipeline:
        """
        Create a dlt pipeline configured for S3/MinIO filesystem destination.

        Args:
            pipeline_name: Unique name for this pipeline (used for state tracking)
            dataset_name: Name of the dataset (becomes a folder prefix in S3)

        Returns:
            Configured dlt.Pipeline ready to run
        """
        # Configure filesystem destination for S3
        # dlt will write Parquet files to: s3://{bucket}/{dataset_name}/{table_name}/
        destination = dlt.destinations.filesystem(
            bucket_url=f"s3://{self.s3_bucket}",
            credentials={
                "aws_access_key_id": self.s3_access_key,
                "aws_secret_access_key": self.s3_secret_key,
                "endpoint_url": self.s3_endpoint,
            },
            # Additional filesystem config
            kwargs={
                "client_kwargs": {
                    "endpoint_url": self.s3_endpoint,
                },
            },
        )

        return dlt.pipeline(
            pipeline_name=pipeline_name,
            destination=destination,
            dataset_name=dataset_name,
            pipelines_dir=self.pipeline_data_dir,
        )

    def run_pipeline(
        self,
        pipeline: dlt.Pipeline,
        source: dlt.sources.DltSource,
        write_disposition: str = "replace",
    ) -> dict:
        """
        Run a dlt pipeline and return load information.

        Args:
            pipeline: The dlt pipeline to run
            source: The dlt source to load from
            write_disposition: How to handle existing data ('replace', 'append', 'merge')

        Returns:
            Dictionary with load statistics and metadata
        """
        load_info = pipeline.run(source, write_disposition=write_disposition)

        # Extract useful metadata
        return {
            "pipeline_name": pipeline.pipeline_name,
            "dataset_name": pipeline.dataset_name,
            "destination": str(pipeline.destination),
            "load_id": load_info.loads_ids[0] if load_info.loads_ids else None,
            "packages_loaded": len(load_info.load_packages) if load_info.load_packages else 0,
            "rows_loaded": sum(
                pkg.jobs_completed for pkg in (load_info.load_packages or [])
            ),
            "started_at": str(load_info.started_at) if load_info.started_at else None,
            "finished_at": str(load_info.finished_at) if load_info.finished_at else None,
        }
