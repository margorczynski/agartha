locals {
  code_sync_script = <<-PYTHON
    #!/usr/bin/env python3
    """Download Dagster user code from S3 (MinIO) to a local directory."""
    import os
    import sys
    import subprocess

    def ensure_boto3():
        try:
            import boto3
        except ImportError:
            subprocess.check_call([sys.executable, "-m", "pip", "install", "-q", "boto3"])

    def sync_code():
        ensure_boto3()
        import boto3
        from botocore.config import Config

        bucket = os.environ["DAGSTER_CODE_BUCKET"]
        prefix = os.environ.get("DAGSTER_CODE_PATH", "")
        dest = os.environ["DAGSTER_CODE_DEST"]

        s3 = boto3.client(
            "s3",
            endpoint_url=os.environ["S3_ENDPOINT"].rstrip("/"),
            aws_access_key_id=os.environ["S3_ACCESS_KEY_ID"],
            aws_secret_access_key=os.environ["S3_SECRET_ACCESS_KEY"],
            region_name=os.environ.get("S3_REGION", "us-east-1"),
            config=Config(s3={"addressing_style": "path"}),
        )

        paginator = s3.get_paginator("list_objects_v2")
        pages = paginator.paginate(Bucket=bucket, Prefix=prefix)

        count = 0
        for page in pages:
            for obj in page.get("Contents", []):
                key = obj["Key"]
                if key.endswith("/"):
                    continue
                # Strip the prefix to get the relative path
                if prefix:
                    rel = key[len(prefix):].lstrip("/")
                else:
                    rel = key
                local_path = os.path.join(dest, rel)
                os.makedirs(os.path.dirname(local_path), exist_ok=True)
                s3.download_file(bucket, key, local_path)
                count += 1

        print(f"Synced {count} files from s3://{bucket}/{prefix} -> {dest}")

        # Install requirements.txt files if present
        pip_target = os.environ.get("DAGSTER_PIP_TARGET", "")
        for root, dirs, files in os.walk(dest):
            if "requirements.txt" in files:
                req_path = os.path.join(root, "requirements.txt")
                print(f"Installing dependencies from {req_path}")
                cmd = [sys.executable, "-m", "pip", "install", "-q", "-r", req_path]
                if pip_target:
                    cmd.extend(["--target", pip_target])
                subprocess.check_call(cmd)

    if __name__ == "__main__":
        sync_code()
  PYTHON
}

resource "kubernetes_config_map_v1" "dagster_code_sync_script" {
  metadata {
    name      = "dagster-code-sync-script"
    namespace = local.namespace
    labels    = local.dagster_labels
  }

  data = {
    "sync_code.py" = local.code_sync_script
  }
}

# Mirror in Spark namespace so Spark driver init containers can mount it
resource "kubernetes_config_map_v1" "dagster_code_sync_script_spark" {
  metadata {
    name      = "dagster-code-sync-script"
    namespace = var.spark_namespace
    labels    = local.dagster_labels
  }

  data = {
    "sync_code.py" = local.code_sync_script
  }
}
