#!/bin/bash
# credit where is due: https://aws.amazon.com/blogs/compute/building-high-throughput-genomic-batch-workflows-on-aws-batch-layer-part-3-of-4/
set -euxo pipefail

export STACK="umccrise"
export AWS_DEV="/dev/xvdb"

# AWS instance introspection
AWS_AZ=$(curl -s http://169.254.169.254/latest/meta-data/placement/availability-zone)
AWS_REGION=$(echo "$EC2_AVAIL_ZONE" | sed -e 's:\([0-9][0-9]*\)[a-z]*\$:\\1:')
AWS_INSTANCE=$(curl http://169.254.169.254/latest/meta-data/instance-id)

# Create a 500GB ST1 volume and fetch its ID
VOL_ID=$(sudo aws ec2 create-volume --region "$AWS_REGION" --availability-zone "$AWS_AZ" --encrypted --size 500 --volume-type st1 | jq -r .VolumeId)

# Wait for the volume to become available (block) and then attach it to the instance
aws ec2 wait volume-available --region "$AWS_REGION" --volume-ids "$VOL_ID" --filters Name=status,Values=available
aws ec2 attach-volume --region "$AWS_REGION" --device "$AWS_DEV" --instance-id "$AWS_INSTANCE" --volume-id "$VOL_ID"
aws ec2 wait volume-in-use --region "$AWS_REGION" --volume-ids "$VOL_ID" --filters Name=attachment.device,Values="$AWS_DEV"

# Make sure attached volume is removed post instance termination
aws ec2 modify-instance-attribute --region "$AWS_REGION" --instance-id "$AWS_INSTANCE" --block-device-mappings "[{\"DeviceName\": \"$AWS_DEV\",\"Ebs\":{\"DeleteOnTermination\":true}}]"

# Wait for $AWS_DEV to show up on the OS level. The above aws "ec2 wait" command is not reliable:
# ERROR: mount check: cannot open /dev/xvdb: No such file or directory
# XXX: Find a better way to do this :/
sleep 10

# Format/mount
sudo mkfs.btrfs -f "$AWS_DEV"
sudo echo -e "$AWS_DEV\t/mnt\tbtrfs\tdefaults\t0\t0" | sudo tee -a /etc/fstab
sudo mount -a

# Inject current AWS Batch ECS cluster ID since it's dynamic (then restart the dockerized ecs-agent)
AWS_CLUSTER_ARN=$(aws ecs list-clusters --region "$AWS_REGION" --output json --query 'clusterArns' | jq -r .[] | grep $STACK | awk -F "/" '{ print $2 }')

sudo sed -i "s/ECS_CLUSTER=\"default\"/ECS_CLUSTER=$AWS_CLUSTER_ARN/" /etc/default/ecs

##XXX: Use systemd instead of this, config files do not seem to be re-read with docker restart
sudo docker restart ecs-agent

# Pull in all reference data to /mnt and uncompress the PCGR databundle
sudo time aws s3 sync s3://umccr-umccrise-refdata-dev/ /mnt
sudo time parallel 'tar xvfz {} -C `dirname {}`' ::: /mnt/Hsapiens/*/PCGR/*databundle*.tgz