provider "aws" {
  region = var.aws_region

  default_tags {
    tags = {
      Project   = "cortex-aes-windows-lab"
      ManagedBy = "terraform"
      Owner     = var.owner_tag
      Purpose   = "koi-aes-pov"
    }
  }
}
