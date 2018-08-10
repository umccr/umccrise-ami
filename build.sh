#!/bin/bash
set -e
set -o pipefail

temp_role=$(vault write aws/sts/ops_admin_no_mfa ttl=15m -format=json)

# assume the packer_role role to get the needed AWS permissions and set the stage for the following packer build
export AWS_REGION=ap-southeast-2
export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq '.data | .access_key' | xargs)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq '.data | .secret_key' | xargs)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq '.data | .security_token' | xargs)

# with the new access credentials packer can now build the AMI
packer build -machine-readable packer.json | sudo tee packer-build.log
