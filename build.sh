#!/bin/bash
set -e
set -o pipefail


# assume the ops_admin_no_mfa role to get the needed AWS permissions and set the stage for the following packer build
export AWS_REGION=ap-southeast-2

temp_role=$(aws sts assume-role --role-arn "arn:aws:iam::620123204273:role/packer_role" --role-session-name "temp_session")

export AWS_ACCESS_KEY_ID=$(echo $temp_role | jq .Credentials.AccessKeyId | xargs)
export AWS_SECRET_ACCESS_KEY=$(echo $temp_role | jq .Credentials.SecretAccessKey | xargs)
export AWS_SESSION_TOKEN=$(echo $temp_role | jq .Credentials.SessionToken | xargs)

# with the new access credentials packer can now build the AMI
packer build -machine-readable packer.json | sudo tee packer-build.log
