#!/bin/bash

# Parameters
PROJECT_KEY=$1
SONAR_SERVER=$2
SONAR_TOKEN=$3

# Fetch SonarQube Quality Gate Status
RESPONSE=$(curl -u "$SONAR_TOKEN:" "$SONAR_SERVER/api/qualitygates/project_status?projectKey=$PROJECT_KEY")
echo "SonarQube Response: $RESPONSE"

STATUS=$(echo "$RESPONSE" | jq -r '.projectStatus.status')
NEW_COVERAGE=$(echo "$RESPONSE" | jq -r '.projectStatus.conditions[] | select(.metricKey=="new_coverage") | .actualValue')
ERROR_THRESHOLD=$(echo "$RESPONSE" | jq -r '.projectStatus.conditions[] | select(.metricKey=="new_coverage") | .errorThreshold')

# Log Output
echo "Status: $STATUS"
echo "New Coverage: $NEW_COVERAGE"
echo "Error Threshold: $ERROR_THRESHOLD"

# Perform floating-point comparison using awk
result=$(awk "BEGIN {if ($NEW_COVERAGE >= $ERROR_THRESHOLD) print 1; else print 0}")

if [ "$result" -eq 0 ]; then
  echo "❌ Pipeline failed: new_coverage ($NEW_COVERAGE) is less than the threshold ($ERROR_THRESHOLD)"
  exit 1
else
  echo "✅ SonarQube Quality Gate passed!"
fi
