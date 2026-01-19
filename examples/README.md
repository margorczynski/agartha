# Agartha Examples

This directory contains example configurations for running data pipelines with Agartha components.

## Getting Credentials

To run these examples, you need to obtain credentials for the deployed Agartha platform.

### MinIO S3 Credentials

1. Retrieve the MinIO access key:
```bash
kubectl get secret minio-tenant-env -n agartha-storage -o jsonpath='{.data.MINIO_ACCESS_KEY_ID}' | base64 -d
```

2. Retrieve the MinIO secret key:
```bash
kubectl get secret minio-tenant-env -n agartha-storage -o jsonpath='{.data.S3_SECRET_ACCESS_KEY}' | base64 -d
```

### Setting Environment Variables

For Python examples (e.g., main.py):
```bash
export MINIO_ACCESS_KEY="<your-access-key>"
export MINIO_SECRET_KEY="<your-secret-key>"
```

For YAML configurations (e.g., spark-etl.yaml, streaming.yaml), replace the placeholders:
- `YOUR_MINIO_ACCESS_KEY` with your MinIO access key
- `YOUR_MINIO_SECRET_KEY` with your MinIO secret key

## Example Directories

- **spark/** - Apache Spark example jobs
- **flink/** - Apache Flink example jobs
- **trino/** - Trino SQL queries

## Notes

- These examples use MinIO's S3-compatible API
- The default MinIO endpoint is `http://minio.agartha-storage.svc.cluster.local:9000`
- Nessie catalog is available at `http://nessie.agartha-catalog.svc.cluster.local:19120/api/v2`
