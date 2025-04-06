provider "aws" {
  region = var.region
}

data "terraform_remote_state" "aws_setup" {
  backend = "s3"
  config = {
    bucket         = var.remote_state_bucket
    key            = var.remote_state_key
    region         = var.aws_region
  }
}

provider "helm" {
  kubernetes {
    host                   = terraform_remote_state.aws_setup.outputs.cluster_endpoint
    cluster_ca_certificate = base64decode(terraform_remote_state.aws_setup.outputs.cluster_ca_certificate)
    token                  = data.aws_eks_cluster_auth.this.token
  }
}

data "aws_eks_cluster_auth" "this" {
  name = terraform_remote_state.aws_setup.outputs.cluster_name
}
