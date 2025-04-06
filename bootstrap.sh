terraform init \
  -backend-config="bucket=my-terraform-state-bucket" \
  -backend-config="key=env/prod/terraform.tfstate" \
  -backend-config="region=us-east-1" \
  -backend-config="dynamodb_table=terraform-state-locking"

terraform init -backend-config="bucket=muplat-test-state-bucket" -backend-config="key=muplat/terraform.tfstate" -backend-config="region=us-east-1" -backend-config="dynamodb_table=muplat-test-state-lock"
