#!/bin/bash
source project-config.env
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE
echo "✅ Environment configured for BGP Security project: $PROJECT_ID"
