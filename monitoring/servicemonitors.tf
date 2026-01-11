# MinIO metrics are behind authentication - using additionalScrapeConfigs instead
# The PodMonitor approach requires complex secret mounting that doesn't work well with
# cross-namespace secrets. Using a simpler approach with additionalScrapeConfigs in Prometheus.
