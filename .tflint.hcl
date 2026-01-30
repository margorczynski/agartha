config = {
  module = true
  force = false
  disabled_by_default = false
  ignore_module = {}

  plugin_dir = "~/.tflint.d/plugins"

  rule_group {
    enabled = true
    name = "aws"
  }

  rule_group {
    enabled = true
    name = "azurerm"
  }

  rule_group {
    enabled = true
    name = "google"
  }

  rule_group {
    enabled = true
    name = "kubernetes"
  }

  rule_group {
    enabled = true
    name = "terraform"
  }

  rule_group {
    enabled = true
    name = "terraform_framework"
  }

  varsfile = ""
}
