#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="agartha-orchestration"
STORAGE_NAMESPACE="agartha-storage"
BUCKET="agartha-dagster-code"
PREFIX="agartha-pipelines"
DEPLOYMENT="dagster-agartha-pipelines"
MC="${SCRIPT_DIR}/mc"

echo "==> Checking prerequisites..."
if ! command -v kubectl &>/dev/null; then
  echo "ERROR: kubectl is not installed" >&2
  exit 1
fi

# Download mc if not present
if [ ! -x "$MC" ]; then
  echo "==> Downloading MinIO client..."
  OS=$(uname -s | tr '[:upper:]' '[:lower:]')
  ARCH=$(uname -m)
  case "$ARCH" in
    x86_64)  ARCH="amd64" ;;
    aarch64) ARCH="arm64" ;;
    arm64)   ARCH="arm64" ;;
    *)       echo "ERROR: Unsupported architecture: $ARCH" >&2; exit 1 ;;
  esac
  curl -sSL "https://dl.min.io/client/mc/release/${OS}-${ARCH}/mc" -o "$MC"
  chmod +x "$MC"
  echo "    Downloaded to $MC"
fi

# Set up port-forward
echo "==> Setting up port-forward to MinIO..."
kubectl port-forward -n "$STORAGE_NAMESPACE" svc/minio 9000:80 &>/dev/null &
PF_PID=$!
trap "kill $PF_PID 2>/dev/null || true" EXIT
sleep 3

# Get S3 credentials
echo "==> Reading S3 credentials..."
S3_ACCESS_KEY=$(kubectl get secret -n "$NAMESPACE" dagster-s3-credentials \
  -o jsonpath='{.data.S3_ACCESS_KEY_ID}' | base64 -d)
S3_SECRET_KEY=$(kubectl get secret -n "$NAMESPACE" dagster-s3-credentials \
  -o jsonpath='{.data.S3_SECRET_ACCESS_KEY}' | base64 -d)

"$MC" alias set agartha http://127.0.0.1:9000 "$S3_ACCESS_KEY" "$S3_SECRET_KEY" --quiet

# Upload code
echo "==> Uploading pipeline code to s3://${BUCKET}/${PREFIX}/..."
"$MC" cp --recursive "${SCRIPT_DIR}/" "agartha/${BUCKET}/${PREFIX}/" --quiet
echo "    Upload complete"

# Restart deployment
echo "==> Restarting deployment ${DEPLOYMENT}..."
kubectl rollout restart deployment "$DEPLOYMENT" -n "$NAMESPACE"

# Wait for rollout
echo "==> Waiting for pod to become ready (this may take a few minutes)..."
kubectl rollout status deployment "$DEPLOYMENT" -n "$NAMESPACE" --timeout=300s

echo "==> Done. Assets should now be visible in the Dagster UI."
