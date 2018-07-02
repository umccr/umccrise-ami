#!/bin/sh -x
# credit where is due: https://aws.amazon.com/blogs/compute/building-high-throughput-genomic-batch-workflows-on-aws-batch-layer-part-3-of-4/

AWS_DEV="/dev/xvdb"
# XXX: AZs on volumes, try to stick to one or make sure instances and volumes are under the same?
AWS_AZ="ap-southeast-2c"
AWS_INSTANCE=`curl https://169.254.169.254/latest/meta-data/instance-id`

# All root operations
sudo su

VOL_ID=aws ec2 create-volume --availability-zone "$AWS_AZ" --encrypted --size 500 --volume-type st1 --tag-specifications "awsbatch" | jq .VolumeId
aws ec2 attach-volume --device "$AWS_DEV" --instance-id "$AWS_INSTANCE" --volume-id "$VOL_ID"

# Format/mount
mkfs -t btrfs "$AWS_DEV"
echo -e "$AWS_DEV\t/mnt\tbtrfs\tdefaults\t0\t0" | tee -a /etc/fstab
mount –a

# XXX: Why not leave the agent running?
# XXX: Need to gather/inject ECS cluster id here anyways
#sudo stop ecs
#sudo rm -rf /var/lib/ecs/data/ecs_agent_data.json

# Pull in all reference data to /mnt
aws s3 sync s3://umccr-primary-data-dev/ /mnt
