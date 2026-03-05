# Remote state backend — S3 + DynamoDB locking.
#
# Bootstrap the bucket and lock table ONCE before `tofu init`:
#
#   tofu -chdir=modules/aws/bootstrap init
#   tofu -chdir=modules/aws/bootstrap apply \
#     -var="state_bucket_name=<bucket>" \
#     -var="region=us-east-1"
#
# Then initialise the root module:
#
#   tofu init -reconfigure
#
# bucket and profile are now inlined in the backend block below.

terraform {
  backend "s3" {
    bucket  = "ethrc-tf"
    key     = "hercules/eks/terraform.tfstate"
    region  = "us-east-1"
    encrypt = true
    profile = "ethrc"
  }
}
