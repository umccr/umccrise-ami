#!/bin/bash -e

APP="pcgr"

# install DataDog Python library
pip install datadog

# Set up
tee ~/.dogrc << END
[Connection]
apikey = ${DATADOG_API_KEY}
appkey = ${DATADOG_APP_KEY}
END

echo "Extracting AMI ID"
ami_id=`grep 'artifact,0,id' packer-build.log | cut -d, -f6 | cut -d: -f2`

echo "Extracted AMI ID: $ami_id. Sending DataDog event..."
dog event post --no_host --tags aws,ami,$APP --type travis "New AMI created" "$ami_id build from commit $TRAVIS_COMMIT"
echo "Event successfully sent."
