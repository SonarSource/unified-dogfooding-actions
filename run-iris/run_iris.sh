#!/bin/bash
set -euo pipefail

: "${ARTIFACTORY_USERNAME?}" "${ARTIFACTORY_ACCESS_TOKEN?}" "${ARTIFACTORY_URL?}"
: "${SONAR_SQC_EU_URL?}" "${SONAR_IRIS_SQC_EU_TOKEN?}"
: "${SONAR_SQC_US_URL?}" "${SONAR_IRIS_SQC_US_TOKEN?}"
: "${SONAR_NEXT_URL?}" "${SONAR_IRIS_NEXT_TOKEN?}"
: "${PRIMARY_PROJECT_KEY?}" "${PRIMARY_PLATFORM?}"
: "${SHADOW1_PROJECT_KEY?}" "${SHADOW1_PLATFORM?}"
: "${SHADOW2_PROJECT_KEY?}" "${SHADOW2_PLATFORM?}"
: "${ORGANIZATION?}"

# Get dependency risk count
function get_dependency_risk_count() {
  local response
  local count

  echo "===== Checking dependency risk count in Next"

  response=$(curl -s \
    -H "Authorization: Bearer $SONAR_IRIS_NEXT_TOKEN" \
    "$SONAR_NEXT_URL/api/v2/sca/issues-releases?projectKey=SonarSource_sonarcloud-codedatalake&riskStatuses=OPEN&severities=MEDIUM,HIGH,BLOCKER")

  if [ $? -ne 0 ]; then
    echo "Failed to fetch issues from API"
    return 1
  fi

  count=$(echo "$response" | jq -r '.page.total // 0' 2>/dev/null)

  # Handle any jq parsing issues or null values
  if [[ "$count" == "null" ]] || [[ -z "$count" ]] || ! [[ "$count" =~ ^[0-9]+$ ]]; then
    echo "Invalid or missing issue count received: '$count', defaulting to 0"
    count=0
  fi

  echo "===== IRIS execution completed. Total dependency risks found: $count"
  echo "total-count=$count" >> "$GITHUB_OUTPUT"
}

# Run IRIS from Next to SQC EU or SQC US
function run_iris_next_to_sqc () {
  local destination_project_key=$1
  local destination_platform=$2
  local dryrun=$3
  local destination_url
  local destination_token

  if [ "$destination_platform" = "SQC-EU" ]; then
    destination_url="$SONAR_SQC_EU_URL"
    destination_token="$SONAR_IRIS_SQC_EU_TOKEN"
  else
    destination_url="$SONAR_SQC_US_URL"
    destination_token="$SONAR_IRIS_SQC_US_TOKEN"
  fi

  java \
    -Diris.source.projectKey="$PRIMARY_PROJECT_KEY" \
    -Diris.source.url="$SONAR_NEXT_URL" \
    -Diris.source.token="$SONAR_IRIS_NEXT_TOKEN" \
    -Diris.destination.projectKey="$destination_project_key" \
    -Diris.destination.organization="$ORGANIZATION" \
    -Diris.destination.url="$destination_url" \
    -Diris.destination.token="$destination_token" \
    -Diris.dryrun="$dryrun" \
    -jar iris-\[RELEASE\]-jar-with-dependencies.jar
}

# Run IRIS from SQC EU to Next or SQC US
function run_iris_sqc_to_next_or_sqc () {
  local destination_project_key=$1
  local destination_platform=$2
  local dryrun=$3
  local destination_url
  local destination_token

  if [ "$destination_platform" = "Next" ]; then
    destination_url="$SONAR_NEXT_URL"
    destination_token="$SONAR_IRIS_NEXT_TOKEN"
    organization=""
  else
    destination_url="$SONAR_SQC_US_URL"
    destination_token="$SONAR_IRIS_SQC_US_TOKEN"
    organization="$ORGANIZATION"
  fi

  java \
    -Diris.source.projectKey="$PRIMARY_PROJECT_KEY" \
    -Diris.source.organization="$ORGANIZATION" \
    -Diris.source.url="$SONAR_SQC_EU_URL" \
    -Diris.source.token="$SONAR_IRIS_SQC_EU_TOKEN" \
    -Diris.destination.projectKey="$destination_project_key" \
    -Diris.destination.organization="$organization" \
    -Diris.destination.url="$destination_url" \
    -Diris.destination.token="$destination_token" \
    -Diris.dryrun="$dryrun" \
    -jar iris-\[RELEASE\]-jar-with-dependencies.jar
}

VERSION="\[RELEASE\]"
HTTP_CODE=$(\
  curl \
    --write-out '%{http_code}' \
    --location \
    --remote-name \
    --user "$ARTIFACTORY_USERNAME:$ARTIFACTORY_ACCESS_TOKEN" \
    "$ARTIFACTORY_URL/sonarsource-private-releases/com/sonarsource/iris/iris/$VERSION/iris-$VERSION-jar-with-dependencies.jar"\
)

if [ "$HTTP_CODE" != "200" ]; then
  echo "Download $VERSION failed -> $HTTP_CODE"
  exit 1
else
  echo "Downloaded $VERSION"
fi

echo "===== Execute IRIS $PRIMARY_PLATFORM to $SHADOW1_PLATFORM as dry-run"
if [ "$PRIMARY_PLATFORM" = "Next" ]; then
  run_iris_next_to_sqc $SHADOW1_PROJECT_KEY $SHADOW1_PLATFORM "true"
else
  run_iris_sqc_to_next_or_sqc $SHADOW1_PROJECT_KEY $SHADOW1_PLATFORM "true"
fi
STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo "===== Failed to run IRIS dry-run"
  exit 1
else
  echo "===== Successful IRIS Next dry-run - executing IRIS for real."
  if [ "$PRIMARY_PLATFORM" = "Next" ]; then
    run_iris_next_to_sqc $SHADOW1_PROJECT_KEY $SHADOW1_PLATFORM "false"
  else
    run_iris_sqc_to_next_or_sqc $SHADOW1_PROJECT_KEY $SHADOW1_PLATFORM "true"
  fi
fi


echo "===== Execute IRIS $PRIMARY_PLATFORM to $SHADOW2_PLATFORM as dry-run"
if [ "$PRIMARY_PLATFORM" = "Next" ]; then
  run_iris_next_to_sqc $SHADOW2_PROJECT_KEY $SHADOW2_PLATFORM "true"
else
  run_iris_sqc_to_next_or_sqc $SHADOW2_PROJECT_KEY $SHADOW2_PLATFORM "true"
fi
STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo "===== Failed to run IRIS dry-run"
  exit 1
else
  echo "===== Successful IRIS Next dry-run - executing IRIS for real."
  if [ "$PRIMARY_PLATFORM" = "Next" ]; then
    run_iris_next_to_sqc $SHADOW2_PROJECT_KEY $SHADOW2_PLATFORM "false"
  else
    run_iris_sqc_to_next_or_sqc $SHADOW1_PROJECT_KEY $SHADOW1_PLATFORM "true"
  fi
fi

# Check for dependency risks after running IRIS
get_dependency_risk_count
