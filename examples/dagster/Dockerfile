FROM docker.io/dagster/dagster-k8s:1.12.11

# Install dlt with filesystem support
# boto3 is added explicitly to ensure version consistency with botocore
RUN pip install --no-cache-dir \
    "dlt[filesystem]>=1.0.0" \
    "s3fs>=2024.2.0" \
    "pyarrow>=15.0.0" \
    "boto3"

# Create dlt state directory
RUN mkdir -p /tmp/dlt_pipelines && chmod 777 /tmp/dlt_pipelines

# Copy pipeline code into image
COPY definitions.py /opt/dagster/app/definitions.py
