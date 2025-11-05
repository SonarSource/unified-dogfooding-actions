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
: "${SKIP_DRY_RUN?}"
: "${STARTDATE?}"

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

# Get startdate parameter if STARTDATE is defined
function get_startdate_param() {
  if [ -n "${STARTDATE:-}" ]; then
    echo "-Diris.startdate=$STARTDATE"
  else
    echo ""
  fi
}

function run_iris () {
  local destination_project_key=$1
  local destination_platform=$2
  local dryrun=$3
  local destination_url
  local destination_token
  local startdate_param=$(get_startdate_param)

  if [ "$SKIP_DRY_RUN" = "true" ] && [ "$dryrun" = "true" ]; then
    echo "===== SKIP_DRY_RUN is true, skipping dry-run execution"
    return 0
  fi

  # Set source attributes
  if [ "$PRIMARY_PLATFORM" = "Next" ]; then
    source_url="$SONAR_NEXT_URL"
    source_token="$SONAR_IRIS_NEXT_TOKEN"
    source_org=""
  elif [ "$PRIMARY_PLATFORM" = "SQC-EU" ]; then
    source_url="$SONAR_SQC_EU_URL"
    source_token="$SONAR_IRIS_SQC_EU_TOKEN"
    source_org="$ORGANIZATION"
  else
    # SQC-US
    source_url="$SONAR_SQC_US_URL"
    source_token="$SONAR_IRIS_SQC_US_TOKEN"
    source_org="$ORGANIZATION"
  fi

  # Set destination attributes
  if [ "$destination_platform" = "Next" ]; then
    destination_url="$SONAR_NEXT_URL"
    destination_token="$SONAR_IRIS_NEXT_TOKEN"
    destination_org=""
  elif [ "$destination_platform" = "SQC-EU" ]; then
    destination_url="$SONAR_SQC_EU_URL"
    destination_token="$SONAR_IRIS_SQC_EU_TOKEN"
    destination_org="$ORGANIZATION"
  else
    # SQC-US
    destination_url="$SONAR_SQC_US_URL"
    destination_token="$SONAR_IRIS_SQC_US_TOKEN"
    destination_org="$ORGANIZATION"
  fi

  java \
    -Diris.source.projectKey="$PRIMARY_PROJECT_KEY" \
    -Diris.source.organization="$source_org" \
    -Diris.source.url="$source_url" \
    -Diris.source.token="$source_token" \
    -Diris.destination.projectKey="$destination_project_key" \
    -Diris.destination.organization="$destination_org" \
    -Diris.destination.url="$destination_url" \
    -Diris.destination.token="$destination_token" \
    -Diris.dryrun="$dryrun" \
    $startdate_param \
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
run_iris $SHADOW1_PROJECT_KEY $SHADOW1_PLATFORM "true"
STATUS=$?
if [ $STATUS -ne 0 ]; then
  echo "===== Failed to run IRIS dry-run"
  exit 1
else
  echo "===== Successful IRIS Next dry-run - executing IRIS for real."
  run_iris $SHADOW1_PROJECT_KEY $SHADOW1_PLATFORM "false"
fi

# Check if SHADOW2_PLATFORM is defined before running IRIS to SHADOW2
if [ -z "${SHADOW2_PLATFORM:-}" ] || [ -z "${SHADOW2_PROJECT_KEY:-}" ]; then
  echo "===== SHADOW2_PLATFORM or SHADOW2_PROJECT_KEY is not defined. Skipping IRIS execution to SHADOW2."
else
  echo "===== Execute IRIS $PRIMARY_PLATFORM to $SHADOW2_PLATFORM as dry-run"
  run_iris $SHADOW2_PROJECT_KEY $SHADOW2_PLATFORM "true"
  STATUS=$?
  if [ $STATUS -ne 0 ]; then
    echo "===== Failed to run IRIS dry-run"
    exit 1
  else
    echo "===== Successful IRIS Next dry-run - executing IRIS for real."
    run_iris $SHADOW2_PROJECT_KEY $SHADOW2_PLATFORM "false"
  fi
fi

# Check for dependency risks after running IRIS
get_dependency_risk_count
