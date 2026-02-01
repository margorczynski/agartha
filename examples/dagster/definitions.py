"""
Dagster definitions for Agartha data platform.

This module defines assets that orchestrate:
1. Spark jobs via the Kubernetes Spark Operator for heavy transformations
2. dlt pipelines for ingesting data from external APIs and sources

Dagster handles orchestration while Spark Operator manages Spark job execution
and dlt handles data extraction and loading.

Note: All code is in a single file to work with Kubernetes ConfigMap mounts
which don't preserve directory structure.
"""

import os
import time
import uuid
from typing import Any, Iterator

import dlt
from dlt.sources.helpers.rest_client import RESTClient
from dlt.sources.helpers.rest_client.paginators import HeaderLinkPaginator

from dagster import (
    AssetExecutionContext,
    AssetSelection,
    Config,
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
# dlt Pipeline Resource
# ============================================================================


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
        destination = dlt.destinations.filesystem(
            bucket_url=f"s3://{self.s3_bucket}",
            credentials={
                "aws_access_key_id": self.s3_access_key,
                "aws_secret_access_key": self.s3_secret_key,
                "endpoint_url": self.s3_endpoint,
            },
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
        """
        load_info = pipeline.run(
            source,
            write_disposition=write_disposition,
            loader_file_format="parquet",
        )

        # Count completed jobs across all load packages
        jobs_completed = 0
        for pkg in (load_info.load_packages or []):
            if hasattr(pkg, "jobs") and isinstance(pkg.jobs, dict):
                jobs_completed += len(pkg.jobs.get("completed_jobs", []))

        return {
            "pipeline_name": pipeline.pipeline_name,
            "dataset_name": pipeline.dataset_name,
            "destination": str(pipeline.destination),
            "load_id": load_info.loads_ids[0] if load_info.loads_ids else None,
            "packages_loaded": len(load_info.load_packages) if load_info.load_packages else 0,
            "jobs_completed": jobs_completed,
            "started_at": str(load_info.started_at) if load_info.started_at else None,
            "finished_at": str(load_info.finished_at) if load_info.finished_at else None,
        }


# ============================================================================
# dlt GitHub Source
# ============================================================================


GITHUB_BASE_URL = "https://api.github.com"


def _get_github_client(access_token: str | None = None) -> RESTClient:
    """Create a REST client for GitHub API with optional authentication."""
    headers = {
        "Accept": "application/vnd.github+json",
        "X-GitHub-Api-Version": "2022-11-28",
    }
    if access_token:
        headers["Authorization"] = f"Bearer {access_token}"

    return RESTClient(
        base_url=GITHUB_BASE_URL,
        headers=headers,
        paginator=HeaderLinkPaginator(),
    )


@dlt.source(name="github")
def github_source(
    organization: str,
    access_token: str | None = dlt.secrets.value,
    max_repos: int = 100,
):
    """
    A dlt source that extracts data from GitHub's REST API.

    Args:
        organization: GitHub organization name to fetch data from
        access_token: Optional GitHub personal access token for higher rate limits
        max_repos: Maximum number of repositories to fetch (default 100)
    """
    client = _get_github_client(access_token)

    @dlt.resource(
        name="repositories",
        write_disposition="replace",
        primary_key="id",
    )
    def repositories() -> Iterator[dict]:
        """Fetch all public repositories for the organization."""
        count = 0
        for page in client.paginate(
            f"/orgs/{organization}/repos",
            params={"type": "public", "sort": "updated", "per_page": 100},
        ):
            for repo in page:
                if count >= max_repos:
                    return
                yield {
                    "id": repo["id"],
                    "name": repo["name"],
                    "full_name": repo["full_name"],
                    "description": repo["description"],
                    "html_url": repo["html_url"],
                    "language": repo["language"],
                    "stargazers_count": repo["stargazers_count"],
                    "watchers_count": repo["watchers_count"],
                    "forks_count": repo["forks_count"],
                    "open_issues_count": repo["open_issues_count"],
                    "created_at": repo["created_at"],
                    "updated_at": repo["updated_at"],
                    "pushed_at": repo["pushed_at"],
                    "default_branch": repo["default_branch"],
                    "archived": repo["archived"],
                    "license_name": repo.get("license", {}).get("name") if repo.get("license") else None,
                }
                count += 1

    @dlt.resource(
        name="contributors",
        write_disposition="replace",
        primary_key=["repo_name", "contributor_id"],
    )
    def contributors() -> Iterator[dict]:
        """Fetch contributors for each repository."""
        count = 0
        for page in client.paginate(
            f"/orgs/{organization}/repos",
            params={"type": "public", "sort": "updated", "per_page": 100},
        ):
            for repo in page:
                if count >= max_repos:
                    return
                repo_name = repo["name"]
                try:
                    for contrib_page in client.paginate(
                        f"/repos/{organization}/{repo_name}/contributors",
                        params={"per_page": 100, "anon": "false"},
                    ):
                        for contributor in contrib_page:
                            yield {
                                "repo_name": repo_name,
                                "contributor_id": contributor["id"],
                                "login": contributor["login"],
                                "avatar_url": contributor["avatar_url"],
                                "contributions": contributor["contributions"],
                                "type": contributor["type"],
                            }
                except Exception:
                    pass
                count += 1

    @dlt.resource(
        name="issues",
        write_disposition="merge",
        primary_key="id",
    )
    def issues(
        updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            "updated_at", initial_value="2020-01-01T00:00:00Z"
        ),
    ) -> Iterator[dict]:
        """Fetch issues for repositories with incremental loading."""
        count = 0
        for page in client.paginate(
            f"/orgs/{organization}/repos",
            params={"type": "public", "sort": "updated", "per_page": 100},
        ):
            for repo in page:
                if count >= max_repos:
                    return
                repo_name = repo["name"]
                try:
                    for issue_page in client.paginate(
                        f"/repos/{organization}/{repo_name}/issues",
                        params={
                            "state": "all",
                            "sort": "updated",
                            "direction": "asc",
                            "since": updated_at.last_value,
                            "per_page": 100,
                        },
                    ):
                        for issue in issue_page:
                            if "pull_request" in issue:
                                continue
                            yield {
                                "id": issue["id"],
                                "repo_name": repo_name,
                                "number": issue["number"],
                                "title": issue["title"],
                                "state": issue["state"],
                                "user_login": issue["user"]["login"] if issue.get("user") else None,
                                "labels": [label["name"] for label in issue.get("labels", [])],
                                "assignees": [a["login"] for a in issue.get("assignees", [])],
                                "comments": issue["comments"],
                                "created_at": issue["created_at"],
                                "updated_at": issue["updated_at"],
                                "closed_at": issue.get("closed_at"),
                            }
                except Exception:
                    pass
                count += 1

    @dlt.resource(
        name="pull_requests",
        write_disposition="merge",
        primary_key="id",
    )
    def pull_requests(
        updated_at: dlt.sources.incremental[str] = dlt.sources.incremental(
            "updated_at", initial_value="2020-01-01T00:00:00Z"
        ),
    ) -> Iterator[dict]:
        """Fetch pull requests for repositories with incremental loading."""
        count = 0
        for page in client.paginate(
            f"/orgs/{organization}/repos",
            params={"type": "public", "sort": "updated", "per_page": 100},
        ):
            for repo in page:
                if count >= max_repos:
                    return
                repo_name = repo["name"]
                try:
                    for pr_page in client.paginate(
                        f"/repos/{organization}/{repo_name}/pulls",
                        params={
                            "state": "all",
                            "sort": "updated",
                            "direction": "asc",
                            "per_page": 100,
                        },
                    ):
                        for pr in pr_page:
                            if pr["updated_at"] < updated_at.last_value:
                                continue
                            yield {
                                "id": pr["id"],
                                "repo_name": repo_name,
                                "number": pr["number"],
                                "title": pr["title"],
                                "state": pr["state"],
                                "user_login": pr["user"]["login"] if pr.get("user") else None,
                                "draft": pr.get("draft", False),
                                "merged_at": pr.get("merged_at"),
                                "created_at": pr["created_at"],
                                "updated_at": pr["updated_at"],
                                "closed_at": pr.get("closed_at"),
                                "head_ref": pr["head"]["ref"],
                                "base_ref": pr["base"]["ref"],
                            }
                except Exception:
                    pass
                count += 1

    return [repositories, contributors, issues, pull_requests]


# ============================================================================
# Spark Operator Resource
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
        default_factory=lambda: os.environ.get("SPARK_IMAGE", "apache/spark:3.5.3-python3"),
        description="Spark container image",
    )
    code_bucket: str = Field(
        default_factory=lambda: os.environ.get("DAGSTER_CODE_BUCKET", "agartha-dagster-code"),
        description="S3 bucket containing pipeline code",
    )
    code_path: str = Field(
        default_factory=lambda: os.environ.get("DAGSTER_CODE_PATH", "agartha-pipelines"),
        description="S3 prefix for this deployment's code",
    )
    sync_image: str = Field(
        default="docker.io/dagster/dagster-k8s:1.12.11",
        description="Image for the init container that syncs code from S3",
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
        """Submit a Spark job and wait for completion."""
        from kubernetes import client, config

        try:
            config.load_incluster_config()
        except config.ConfigException:
            config.load_kube_config()

        api = client.CustomObjectsApi()

        job_id = str(uuid.uuid4())[:8]
        job_name = f"dagster-{script_name.replace('.py', '').replace('_', '-')}-{job_id}"

        spark_app = self._create_spark_application(job_name, script_name)

        context.log.info(f"Submitting SparkApplication: {job_name}")

        api.create_namespaced_custom_object(
            group="sparkoperator.k8s.io",
            version="v1beta2",
            namespace=self.namespace,
            plural="sparkapplications",
            body=spark_app,
        )

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
                raise Failure(description=f"Spark job {job_name} failed: {error_msg}. Job NOT deleted for debugging - run: kubectl logs -n {self.namespace} {job_name}-driver")

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
                "sparkVersion": "3.5.3",
                "restartPolicy": {"type": "Never"},
                "sparkConf": {
                    "spark.sql.extensions": (
                        "org.apache.iceberg.spark.extensions.IcebergSparkSessionExtensions,"
                        "org.projectnessie.spark.extensions.NessieSparkSessionExtensions"
                    ),
                    "spark.sql.catalog.agartha": "org.apache.iceberg.spark.SparkCatalog",
                    "spark.sql.catalog.agartha.catalog-impl": "org.apache.iceberg.nessie.NessieCatalog",
                    "spark.sql.catalog.agartha.uri": self.nessie_uri,
                    "spark.sql.catalog.agartha.ref": "main",
                    "spark.sql.catalog.agartha.warehouse": self.s3_warehouse,
                    "spark.hadoop.fs.s3a.endpoint": self.s3_endpoint,
                    "spark.hadoop.fs.s3a.access.key": self.s3_access_key,
                    "spark.hadoop.fs.s3a.secret.key": self.s3_secret_key,
                    "spark.hadoop.fs.s3a.path.style.access": "true",
                    "spark.hadoop.fs.s3a.impl": "org.apache.hadoop.fs.s3a.S3AFileSystem",
                    "spark.hadoop.fs.s3a.connection.ssl.enabled": "false",
                    "spark.executor.processTreeMetrics.enabled": "false",
                    "spark.metrics.conf.*.sink.prometheusServlet.class": "org.apache.spark.metrics.sink.PrometheusServlet",
                    "spark.metrics.conf.*.source.jvm.class": "org.apache.spark.metrics.source.JvmSource",
                    "spark.ui.prometheus.enabled": "false",
                    "spark.driver.extraJavaOptions": "-Dcom.sun.management.jmxremote=false -XX:+UseContainerSupport",
                    "spark.executor.extraJavaOptions": "-Dcom.sun.management.jmxremote=false -XX:+UseContainerSupport",
                },
                "deps": {
                    "jars": [],
                    "packages": [
                        "org.apache.iceberg:iceberg-spark-runtime-3.5_2.12:1.5.0",
                        "org.projectnessie.nessie-integrations:nessie-spark-extensions-3.5_2.12:0.79.0",
                        "org.apache.hadoop:hadoop-aws:3.3.4",
                        "software.amazon.awssdk:bundle:2.24.8",
                        "software.amazon.awssdk:url-connection-client:2.24.8",
                    ],
                },
                "driver": {
                    "cores": 1,
                    "coreLimit": "1200m",
                    "memory": "1g",
                    "labels": {"version": "3.5.3"},
                    "serviceAccount": self.service_account,
                    "initContainers": [
                        {
                            "name": "sync-scripts",
                            "image": self.sync_image,
                            "command": [
                                "python", "-c",
                                "import subprocess, sys; "
                                "subprocess.check_call([sys.executable, '-m', 'pip', 'install', '-q', 'boto3']); "
                                "import boto3; "
                                "from botocore.config import Config; "
                                "import os; "
                                f"bucket = '{self.code_bucket}'; "
                                f"prefix = '{self.code_path}/spark_jobs'; "
                                f"dest = '{self.scripts_mount_path}'; "
                                f"s3 = boto3.client('s3', endpoint_url='{self.s3_endpoint}'.rstrip('/'), "
                                f"aws_access_key_id='{self.s3_access_key}', "
                                f"aws_secret_access_key='{self.s3_secret_key}', "
                                "region_name='us-east-1', "
                                "config=Config(s3={'addressing_style': 'path'})); "
                                "pages = s3.get_paginator('list_objects_v2').paginate(Bucket=bucket, Prefix=prefix); "
                                "[("
                                "os.makedirs(os.path.dirname(os.path.join(dest, k[len(prefix):].lstrip('/'))), exist_ok=True), "
                                "s3.download_file(bucket, k, os.path.join(dest, k[len(prefix):].lstrip('/')))"
                                ") for p in pages for o in p.get('Contents', []) "
                                "if not (k := o['Key']).endswith('/')]; "
                                "print(f'Synced scripts from s3://{bucket}/{prefix} -> {dest}')",
                            ],
                            "volumeMounts": [
                                {"name": "spark-scripts", "mountPath": self.scripts_mount_path},
                            ],
                        },
                    ],
                    "volumeMounts": [
                        {"name": "spark-scripts", "mountPath": self.scripts_mount_path},
                        {"name": "ivy-cache", "mountPath": "/home/spark/.ivy2"},
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
                    "labels": {"version": "3.5.3"},
                    "volumeMounts": [
                        {"name": "spark-scripts", "mountPath": self.scripts_mount_path},
                        {"name": "ivy-cache", "mountPath": "/home/spark/.ivy2"},
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
                    {"name": "spark-scripts", "emptyDir": {}},
                    {"name": "ivy-cache", "emptyDir": {}},
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
            pass


# ============================================================================
# Spark Assets - Process dlt data into Iceberg tables
# ============================================================================


@asset(
    group_name="raw_iceberg",
    description="GitHub repositories loaded from dlt Parquet into Iceberg table",
    compute_kind="spark",
    deps=["github_repositories"],
)
def raw_iceberg_github_repos(
    context: AssetExecutionContext,
    spark_operator: SparkOperatorResource,
) -> MaterializeResult:
    """Load GitHub repositories from dlt Parquet files into Iceberg table."""
    result = spark_operator.submit_and_wait(context, "raw_github_repos.py")

    return MaterializeResult(
        metadata={
            "spark_job": MetadataValue.text(result["job_name"]),
            "table": MetadataValue.text("agartha.raw.github_repositories"),
        }
    )


@asset(
    group_name="raw_iceberg",
    description="GitHub contributors loaded from dlt Parquet into Iceberg table",
    compute_kind="spark",
    deps=["github_contributors"],
)
def raw_iceberg_github_contributors(
    context: AssetExecutionContext,
    spark_operator: SparkOperatorResource,
) -> MaterializeResult:
    """Load GitHub contributors from dlt Parquet files into Iceberg table."""
    result = spark_operator.submit_and_wait(context, "raw_github_contributors.py")

    return MaterializeResult(
        metadata={
            "spark_job": MetadataValue.text(result["job_name"]),
            "table": MetadataValue.text("agartha.raw.github_contributors"),
        }
    )


@asset(
    group_name="curated",
    description="Curated GitHub repositories with validation and enrichment",
    deps=[raw_iceberg_github_repos],
    compute_kind="spark",
)
def curated_github_repos(
    context: AssetExecutionContext,
    spark_operator: SparkOperatorResource,
) -> MaterializeResult:
    """Curate GitHub repositories with data quality rules and enrichment."""
    result = spark_operator.submit_and_wait(context, "curated_github_repos.py")

    return MaterializeResult(
        metadata={
            "spark_job": MetadataValue.text(result["job_name"]),
            "table": MetadataValue.text("agartha.curated.github_repositories"),
        }
    )


@asset(
    group_name="analytics",
    description="GitHub repository analytics (language stats, activity, org summary)",
    deps=[curated_github_repos],
    compute_kind="spark",
)
def github_repo_analytics(
    context: AssetExecutionContext,
    spark_operator: SparkOperatorResource,
) -> MaterializeResult:
    """Compute GitHub repository analytics aggregations."""
    result = spark_operator.submit_and_wait(context, "github_repo_analytics.py")

    return MaterializeResult(
        metadata={
            "spark_job": MetadataValue.text(result["job_name"]),
            "tables": MetadataValue.text(
                "agartha.analytics.github_language_stats, "
                "agartha.analytics.github_activity_summary, "
                "agartha.analytics.github_org_summary"
            ),
        }
    )


# ============================================================================
# dlt Assets - External Data Ingestion
# ============================================================================


class GitHubIngestionConfig(Config):
    """Configuration for GitHub data ingestion."""

    organization: str = Field(
        default="anthropics",
        description="GitHub organization to fetch data from",
    )
    max_repos: int = Field(
        default=50,
        description="Maximum number of repositories to fetch",
    )


@asset(
    group_name="raw_external",
    description="GitHub repositories data ingested via dlt",
    compute_kind="dlt",
)
def github_repositories(
    context: AssetExecutionContext,
    config: GitHubIngestionConfig,
    dlt_pipeline: DltPipelineResource,
) -> MaterializeResult:
    """Ingest GitHub repository data for an organization."""
    context.log.info(f"Fetching GitHub data for organization: {config.organization}")

    pipeline = dlt_pipeline.create_pipeline(
        pipeline_name="github_ingestion",
        dataset_name="github",
    )

    source = github_source(
        organization=config.organization,
        max_repos=config.max_repos,
    ).with_resources("repositories")

    context.log.info("Running dlt pipeline for repositories...")
    load_info = dlt_pipeline.run_pipeline(pipeline, source, write_disposition="replace")

    context.log.info(f"dlt pipeline completed: {load_info}")

    return MaterializeResult(
        metadata={
            "organization": MetadataValue.text(config.organization),
            "pipeline": MetadataValue.text(load_info["pipeline_name"]),
            "dataset": MetadataValue.text(load_info["dataset_name"]),
            "load_id": MetadataValue.text(load_info.get("load_id", "N/A")),
            "destination": MetadataValue.text(f"s3://agartha-raw/github/repositories/"),
        }
    )


@asset(
    group_name="raw_external",
    description="GitHub contributors data ingested via dlt",
    compute_kind="dlt",
    deps=[github_repositories],
)
def github_contributors(
    context: AssetExecutionContext,
    config: GitHubIngestionConfig,
    dlt_pipeline: DltPipelineResource,
) -> MaterializeResult:
    """Ingest GitHub contributor data for repositories."""
    context.log.info(f"Fetching contributors for organization: {config.organization}")

    pipeline = dlt_pipeline.create_pipeline(
        pipeline_name="github_ingestion",
        dataset_name="github",
    )

    source = github_source(
        organization=config.organization,
        max_repos=config.max_repos,
    ).with_resources("contributors")

    context.log.info("Running dlt pipeline for contributors...")
    load_info = dlt_pipeline.run_pipeline(pipeline, source, write_disposition="replace")

    return MaterializeResult(
        metadata={
            "organization": MetadataValue.text(config.organization),
            "pipeline": MetadataValue.text(load_info["pipeline_name"]),
            "load_id": MetadataValue.text(load_info.get("load_id", "N/A")),
            "destination": MetadataValue.text(f"s3://agartha-raw/github/contributors/"),
        }
    )


@asset(
    group_name="raw_external",
    description="GitHub issues data with incremental loading via dlt",
    compute_kind="dlt",
    deps=[github_repositories],
)
def github_issues(
    context: AssetExecutionContext,
    config: GitHubIngestionConfig,
    dlt_pipeline: DltPipelineResource,
) -> MaterializeResult:
    """Ingest GitHub issues with incremental loading."""
    context.log.info(f"Fetching issues for organization: {config.organization}")

    pipeline = dlt_pipeline.create_pipeline(
        pipeline_name="github_ingestion",
        dataset_name="github",
    )

    source = github_source(
        organization=config.organization,
        max_repos=config.max_repos,
    ).with_resources("issues")

    context.log.info("Running dlt pipeline for issues (incremental)...")
    load_info = dlt_pipeline.run_pipeline(pipeline, source, write_disposition="merge")

    return MaterializeResult(
        metadata={
            "organization": MetadataValue.text(config.organization),
            "pipeline": MetadataValue.text(load_info["pipeline_name"]),
            "load_id": MetadataValue.text(load_info.get("load_id", "N/A")),
            "destination": MetadataValue.text(f"s3://agartha-raw/github/issues/"),
            "incremental": MetadataValue.bool(True),
        }
    )


@asset(
    group_name="raw_external",
    description="GitHub pull requests data with incremental loading via dlt",
    compute_kind="dlt",
    deps=[github_repositories],
)
def github_pull_requests(
    context: AssetExecutionContext,
    config: GitHubIngestionConfig,
    dlt_pipeline: DltPipelineResource,
) -> MaterializeResult:
    """Ingest GitHub pull requests with incremental loading."""
    context.log.info(f"Fetching pull requests for organization: {config.organization}")

    pipeline = dlt_pipeline.create_pipeline(
        pipeline_name="github_ingestion",
        dataset_name="github",
    )

    source = github_source(
        organization=config.organization,
        max_repos=config.max_repos,
    ).with_resources("pull_requests")

    context.log.info("Running dlt pipeline for pull requests (incremental)...")
    load_info = dlt_pipeline.run_pipeline(pipeline, source, write_disposition="merge")

    return MaterializeResult(
        metadata={
            "organization": MetadataValue.text(config.organization),
            "pipeline": MetadataValue.text(load_info["pipeline_name"]),
            "load_id": MetadataValue.text(load_info.get("load_id", "N/A")),
            "destination": MetadataValue.text(f"s3://agartha-raw/github/pull_requests/"),
            "incremental": MetadataValue.bool(True),
        }
    )


# ============================================================================
# Jobs and Schedules
# ============================================================================

# Full GitHub pipeline: dlt ingestion -> Spark raw -> curated -> analytics
github_full_pipeline_job = define_asset_job(
    name="github_full_pipeline",
    description="Full GitHub ETL: dlt ingestion -> Iceberg raw -> curated -> analytics",
    selection=AssetSelection.groups("raw_external", "raw_iceberg", "curated", "analytics"),
)

# Just the dlt ingestion (for testing or partial runs)
github_ingestion_job = define_asset_job(
    name="github_ingestion",
    description="Ingest GitHub data via dlt (Parquet to S3)",
    selection=AssetSelection.groups("raw_external"),
)

# Just the Spark processing (assumes dlt data already exists)
github_spark_pipeline_job = define_asset_job(
    name="github_spark_pipeline",
    description="Process GitHub data: Parquet -> Iceberg raw -> curated -> analytics",
    selection=AssetSelection.groups("raw_iceberg", "curated", "analytics"),
)

daily_github_pipeline_schedule = ScheduleDefinition(
    name="daily_github_pipeline",
    job=github_full_pipeline_job,
    cron_schedule="0 2 * * *",
    description="Daily full GitHub data pipeline",
)


# ============================================================================
# Definitions
# ============================================================================

defs = Definitions(
    assets=[
        # dlt assets - ingest from GitHub API to S3 Parquet
        github_repositories,
        github_contributors,
        github_issues,
        github_pull_requests,
        # Spark assets - load Parquet to Iceberg raw layer
        raw_iceberg_github_repos,
        raw_iceberg_github_contributors,
        # Spark assets - curated layer
        curated_github_repos,
        # Spark assets - analytics layer
        github_repo_analytics,
    ],
    resources={
        "spark_operator": SparkOperatorResource(),
        "dlt_pipeline": DltPipelineResource(),
    },
    jobs=[github_full_pipeline_job, github_ingestion_job, github_spark_pipeline_job],
    schedules=[daily_github_pipeline_schedule],
)
