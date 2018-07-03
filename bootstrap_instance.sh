#!/bin/bash
# credit where is due: https://aws.amazon.com/blogs/compute/building-high-throughput-genomic-batch-workflows-on-aws-batch-layer-part-3-of-4/
set -euxo pipefail

AWS_DEV="/dev/xvdb"
# XXX: AZs on volumes, try to stick to one or make sure instances and volumes are under the same? How to pull this off reliably
# when this is basically a managed spot fleet under Batch? :/
AWS_AZ="ap-southeast-2c"
REGION="ap-southeast-2"
AWS_INSTANCE=$(curl http://169.254.169.254/latest/meta-data/instance-id)

# Create a 500GB ST1 volume and fetch its ID
VOL_ID=$(sudo aws ec2 create-volume --region "$REGION" --availability-zone "$AWS_AZ" --encrypted --size 500 --volume-type st1 | jq -r .VolumeId)

# Wait for the volume to become available (block) and then attach it to the instance
aws ec2 wait volume-available --region "$REGION" --volume-ids "$VOL_ID" --filters Name=status,Values=available
aws ec2 attach-volume --region "$REGION" --device "$AWS_DEV" --instance-id "$AWS_INSTANCE" --volume-id "$VOL_ID"
aws ec2 wait volume-in-use --region "$REGION" --volume-ids "$VOL_ID" --filters Name=attachment.device,Values="$AWS_DEV"

# Make sure attached volume is removed post instance termination
aws ec2 modify-instance-attribute --region "$REGION" --instance-id "$AWS_INSTANCE" --block-device-mappings "[{\"DeviceName\": \"$AWS_DEV\",\"Ebs\":{\"DeleteOnTermination\":true}}]"

# Wait for $AWS_DEV to show up on the OS level. The above aws "ec2 wait" command is not reliable:
# ERROR: mount check: cannot open /dev/xvdb: No such file or directory
# XXX: Find a better way to do this :/
sleep 10

# Format/mount
sudo mkfs.btrfs -f "$AWS_DEV"
sudo echo -e "$AWS_DEV\t/mnt\tbtrfs\tdefaults\t0\t0" | tee -a /etc/fstab
sudo mount -a

# Inject current AWS Batch ECS cluster ID since it's dynamic
aws ecs list-clusters --output text --query 'clusterArns' | awk -F "/" '{ print $2 }' > /etc/default/ecs-cluster-arn

# Pull in all reference data to /mnt
sudo time aws s3 sync s3://umccr-umccrise-refdata-dev/ /mnt
#sudo time aws s3 sync s3://umccr-primary-data-dev/ /mnt
