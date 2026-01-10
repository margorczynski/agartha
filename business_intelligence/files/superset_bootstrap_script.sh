#!/bin/bash
pip install --target=/app/.venv/lib/python3.10/site-packages trino psycopg2-binary &&\
if [ ! -f ~/bootstrap ]; then echo "Running Superset with uid {{ .Values.runAsUser }}" > ~/bootstrap; fi