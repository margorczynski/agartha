locals {
  agartha_host             = "agartha.${var.ingress_host}"
  storage_s3_access_key    = "agartha"
  storage_s3_secret_key    = "superpass"
  s3_warehouse_bucket_name = "agartha-warehouse"
}