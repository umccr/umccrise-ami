#!/bin/bash -e
set -e
set -o pipefail

APP=$1
TAGS=$2

DATADOG_API_KEY=$(vault kv get -format=json kv/datadog | jq -r '.data.api_key')

event_text="%%% \n $TRAVIS_REPO_SLUG: new build (no [$TRAVIS_BUILD_NUMBER](https://travis-ci.org/umccr/test-vault-secrets-injection/builds/$TRAVIS_BUILD_ID)) on branch $TRAVIS_BRANCH succeeded for commit [${TRAVIS_COMMIT:0:12}](https://github.com/umccr/test-vault-secrets-injection/commit/${TRAVIS_COMMIT}) \n %%%"

echo "Generating DataDog event"
curl -X POST -H "Content-type: application/json" \
-d "{
      \"title\": \"New $APP event created\",
      \"text\": \"$event_text\",
      \"priority\": \"normal\",
      \"tags\": [\"$TAGS\"],
      \"alert_type\": \"info\"
}" \
"https://api.datadoghq.com/api/v1/events?api_key=$DATADOG_API_KEY"

echo "Event successfully sent."
