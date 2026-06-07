#!/usr/bin/env bash
set -euo pipefail

project="$(gcloud config get-value project 2>/dev/null || true)"
if [[ -z "$project" || "$project" == "(unset)" ]]; then
  echo "gcloud_project=missing"
  echo "Set a Google Cloud project first: gcloud config set project PROJECT_ID"
  exit 1
fi

url="https://console.cloud.google.com/auth/clients?project=${project}"
echo "opening_google_auth_clients=true"
/usr/bin/open "$url"
