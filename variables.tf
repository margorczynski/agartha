variable "kubernetes_config_path" {
  type        = string
  description = "The config path for Kubernetes"
}

variable "ingress_host" {
  type        = string
  description = "The host for ingress access"
}

variable "storage_s3_access_key" {
  type        = string
  description = "The S3 access key to be created and used for the root user"
}

variable "storage_s3_secret_key" {
  type        = string
  description = "The S3 secret key to be created and used for the root user"
}

variable "storage_s3_warehouse_bucket_name" {
  type        = string
  description = "The S3 bucket name to be created and used for storing the data"
}