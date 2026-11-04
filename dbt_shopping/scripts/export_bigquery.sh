#!/usr/bin/env bash
# Exporte la table BigQuery écrite par le job Spark vers GCS en Parquet.
set -euo pipefail
PROJECT="spark-streaming-483317"
TABLE="shopping_dev.orders"
BUCKET="${1:?Usage: ./export_bigquery.sh <nom-du-bucket>}"

bq --project_id="$PROJECT" extract \
  --destination_format=PARQUET \
  "$PROJECT:$TABLE" \
  "gs://$BUCKET/exports/orders/orders-*.parquet"

gsutil ls "gs://$BUCKET/exports/orders/"
