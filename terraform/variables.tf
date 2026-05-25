variable "region" {
  type        = string
  default     = "us-east-1"
  description = "Cheapest standard region; closest to East Coast."
}

variable "bucket_name" {
  type        = string
  description = "Globally unique S3 bucket name. Set in terraform.tfvars (gitignored) so it stays out of the public repo."
}

# No default — must be supplied so terraform refuses to run against the wrong
# AWS account if multiple sets of creds are configured locally. Set via either
# a gitignored terraform.tfvars file:
#   echo 'aws_account_id = "123456789012"' > terraform.tfvars
# or environment variable:
#   export TF_VAR_aws_account_id=123456789012
variable "aws_account_id" {
  type        = string
  description = "AWS account ID this terraform must target. Apply fails if creds resolve elsewhere."
}

variable "aws_profile" {
  type        = string
  description = "Local ~/.aws/credentials profile to use. Set in terraform.tfvars."
}
