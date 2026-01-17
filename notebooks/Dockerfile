FROM quay.io/jupyter/scipy-notebook:latest

USER root

# Install system dependencies
RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

USER ${NB_UID}

# Install Python packages for data exploration with Iceberg/Nessie
RUN pip install --no-cache-dir \
    # Core data libraries
    polars>=1.0.0 \
    pyarrow>=15.0.0 \
    # Iceberg and catalog support
    "pyiceberg[s3fs,pyarrow]>=0.7.0" \
    # S3 access
    s3fs>=2024.2.0 \
    boto3 \
    # Database connectivity
    sqlalchemy \
    trino \
    # Additional useful libraries
    duckdb \
    httpx \
    rich \
    # Visualization
    plotly \
    altair

# Create directory for example notebooks
RUN mkdir -p /home/${NB_USER}/examples

# Copy example notebooks (will be added via ConfigMap)
COPY --chown=${NB_UID}:${NB_GID} examples/ /home/${NB_USER}/examples/

WORKDIR /home/${NB_USER}
