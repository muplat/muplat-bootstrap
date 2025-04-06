#!/usr/bin/env bash

set -e

# Usage check
if [ $# -ne 2 ]; then
  echo "Usage: $0 <region> <bucket_name>"
  exit 1
fi

REGION="$1"
BUCKET_NAME="$2"
AWS_SETUP_RS_KEY="muplat/aws-setup/terraform.tfstate"
k8S_SETUP_RS_KEY="muplat/k8s-setup/terraform.tfstate"

echo "Parameters received:"
echo "  Region: $REGION"
echo "  Bucket: $BUCKET_NAME"
echo

################################################################################
# 1. Check if the bucket exists; if not, create it
################################################################################

echo "Checking if S3 bucket '$BUCKET_NAME' exists..."
if aws s3api head-bucket --bucket "$BUCKET_NAME" --region "$REGION" 2>/dev/null; then
  echo "Bucket '$BUCKET_NAME' already exists."
else
  echo "Bucket '$BUCKET_NAME' does not exist. Creating..."
  if [ "$REGION" = "us-east-1" ]; then
    # For us-east-1, do NOT specify the location constraint
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION"
  else
    # For other regions, specify the location constraint
    aws s3api create-bucket \
      --bucket "$BUCKET_NAME" \
      --region "$REGION" \
      --create-bucket-configuration LocationConstraint="$REGION"
  fi
fi
echo

################################################################################
# 2. Move into aws-setup directory and run Terraform with S3 locking
################################################################################

echo "Moving into aws-setup directory..."
cd aws-setup

echo "Initializing Terraform with remote state backend (S3 locking)..."
terraform init \
  -backend-config="bucket=$BUCKET_NAME" \
  -backend-config="key=$AWS_SETUP_RS_KEY" \
  -backend-config="region=$REGION" \
  -backend-config="use_lockfile=true"

echo
echo "Applying Terraform configuration..."
terraform apply -auto-approve -var "region=$REGION"
CLUSTER_NAME=$(terraform output | grep cluster_name | awk '{print $3}' | tr -d '"')

echo
echo "Done, starting k8s setup"

cd ../k8s-setup
terraform init \
  -backend-config="bucket=$BUCKET_NAME" \
  -backend-config="key=$K8S_SETUP_RS_KEY" \
  -backend-config="region=$REGION" \
  -backend-config="use_lockfile=true"

echo
echo "Applying Terraform configuration..."
terraform apply -auto-approve -var "region=$REGION" -var "remote_state_key=$AWS_SETUP_RS_KEY" -var "remote_state_bucket=$BUCKET_NAME"

echo
echo "Done. Run this command in order to update kubeconfig:"

echo
echo "aws eks update-kubeconfig --name ${CLUSTER_NAME} --region ${REGION}"
