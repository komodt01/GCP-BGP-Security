# Linux Commands Reference
*Complete command reference for BGP Security project deployment and management*

## 🚀 Initial Environment Setup

### **System Dependencies Installation**
```bash
# Update package manager
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y \
  curl \
  jq \
  python3 \
  python3-pip \
  git \
  unzip \
  wget

# Verify installations
curl --version
jq --version
python3 --version
```

### **Google Cloud CLI Installation**
```bash
# Download and install Google Cloud CLI
curl https://sdk.cloud.google.com | bash

# Restart shell to load gcloud
exec -l $SHELL

# Initialize gcloud
gcloud init

# Authenticate with Google Cloud
gcloud auth login
gcloud auth application-default login

# Verify installation
gcloud version
gcloud config list
```

### **Terraform Installation**
```bash
# Add HashiCorp GPG key
curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -

# Add HashiCorp repository
sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"

# Install Terraform
sudo apt-get update && sudo apt-get install terraform

# Verify installation
terraform version
```

### **Python Dependencies Installation**
```bash
# Install Python packages for local development
pip3 install --user \
  requests \
  google-cloud-monitoring \
  google-cloud-bigquery \
  google-cloud-pubsub \
  functions-framework

# Verify Python packages
pip3 list | grep google-cloud
```

## 🏗️ Project Setup Commands

### **Project Structure Creation**
```bash
# Create main project directory
mkdir gcp-bgp-security && cd gcp-bgp-security

# Create complete directory structure
mkdir -p {terraform/{01-foundation,02-networking,03-security,04-compute,05-data,06-monitoring},src/{cloud-functions,cloud-run,bigquery},monitoring/{dashboards,alerts},docs,tests}

# Create initial files
touch terraform/01-foundation/{providers.tf,variables.tf,outputs.tf,main.tf}
touch src/cloud-functions/bgp-validator/{main.py,requirements.txt}
touch {README.md,technologies.md,lessonslearned.md}

# Verify structure
tree . -L 3
```

### **Environment Configuration**
```bash
# Set project variables
export PROJECT_ID="bgp-security-dev"
export PROJECT_NUMBER="908981150758"
export BILLING_ACCOUNT="014DB8-1FDD2F-74D8F5"
export REGION="us-central1"
export ZONE="us-central1-a"

# Configure gcloud
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE

# Save configuration for future sessions
cat > project-config.env << EOF
export PROJECT_ID="$PROJECT_ID"
export PROJECT_NUMBER="$PROJECT_NUMBER"
export BILLING_ACCOUNT="$BILLING_ACCOUNT"
export REGION="$REGION"
export ZONE="$ZONE"
export OWNER_EMAIL="$(git config user.email || echo 'your-email@example.com')"
EOF

# Create environment loader script
cat > setup-env.sh << 'EOF'
#!/bin/bash
source project-config.env
gcloud config set project $PROJECT_ID
gcloud config set compute/region $REGION
gcloud config set compute/zone $ZONE
echo "✅ Environment configured for BGP Security project: $PROJECT_ID"
EOF

chmod +x setup-env.sh
```

## ☁️ Google Cloud Platform Setup

### **Project Creation and Configuration**
```bash
# Create new GCP project (if needed)
gcloud projects create $PROJECT_ID --name="BGP Security Project"

# Link billing account
gcloud billing projects link $PROJECT_ID --billing-account=$BILLING_ACCOUNT

# Verify project setup
gcloud projects describe $PROJECT_ID
gcloud billing projects describe $PROJECT_ID --format="value(billingEnabled)"
```

### **API Enablement**
```bash
# Enable required Google Cloud APIs
gcloud services enable \
  compute.googleapis.com \
  cloudfunctions.googleapis.com \
  bigquery.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  pubsub.googleapis.com \
  storage.googleapis.com \
  secretmanager.googleapis.com \
  run.googleapis.com \
  cloudbuild.googleapis.com \
  cloudresourcemanager.googleapis.com \
  iam.googleapis.com

# Wait for APIs to be fully enabled
sleep 30

# Verify APIs are enabled
gcloud services list --enabled --filter="name:cloudfunctions.googleapis.com OR name:monitoring.googleapis.com"
```

### **IAM Configuration**
```bash
# Get project number for IAM bindings
PROJECT_NUMBER=$(gcloud projects describe $PROJECT_ID --format="value(projectNumber)")

# Grant Cloud Build service account necessary roles
gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
    --role="roles/logging.logWriter"

gcloud projects add-iam-policy-binding $PROJECT_ID \
    --member="serviceAccount:${PROJECT_NUMBER}@cloudbuild.gserviceaccount.com" \
    --role="roles/storage.objectViewer"

# Verify IAM bindings
gcloud projects get-iam-policy $PROJECT_ID --flatten="bindings[].members" --format="table(bindings.role,bindings.members)"
```

## 🛠️ Development Commands

### **Cloud Function Development**
```bash
# Navigate to function directory
cd src/cloud-functions/bgp-validator

# Create requirements.txt
cat > requirements.txt << 'EOF'
requests>=2.28.0
functions-framework>=3.2.0
google-cloud-monitoring>=2.11.0
EOF

# Test function locally
functions-framework --target=bgp_validator --debug --port=8080

# Alternative local testing with Python HTTP server
python3 bgp_validator_standalone.py

# Test function endpoint
curl -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{"prefix": "8.8.8.0/24", "origin_as": 15169, "as_path": [64512, 15169]}'
```

### **Function Testing Commands**
```bash
# Test various BGP scenarios
# Valid Google route
curl -s -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{"prefix": "8.8.8.0/24", "origin_as": 15169, "as_path": [64512, 15169]}' | jq '.'

# Malicious route (ASN 666)
curl -s -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{"prefix": "8.8.8.0/24", "origin_as": 666, "as_path": [64512, 666]}' | jq '.'

# AS path loop
curl -s -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{"prefix": "203.0.113.0/24", "origin_as": 64496, "as_path": [64512, 64496, 64512]}' | jq '.'

# Long AS path
curl -s -X POST http://localhost:8080 \
  -H "Content-Type: application/json" \
  -d '{"prefix": "198.51.100.0/24", "origin_as": 65010, "as_path": [64512, 65001, 65002, 65003, 65004, 65005, 65006, 65007, 65008, 65009, 65010]}' | jq '.'
```

## 🚀 Deployment Commands

### **Cloud Function Deployment**
```bash
# Deploy BGP validator function
gcloud functions deploy bgp-validator \
  --runtime python39 \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point bgp_validator \
  --memory 512MB \
  --timeout 60s \
  --project $PROJECT_ID \
  --region $REGION

# Get function URL
FUNCTION_URL=$(gcloud functions describe bgp-validator --region=$REGION --format="value(httpsTrigger.url)")
echo "Function deployed at: $FUNCTION_URL"

# Test deployed function
curl -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"prefix": "8.8.8.0/24", "origin_as": 15169, "as_path": [64512, 15169]}' | jq '.'
```

### **Function Management Commands**
```bash
# View function details
gcloud functions describe bgp-validator --region=$REGION

# View function logs
gcloud functions logs read bgp-validator --region=$REGION --limit=10

# View real-time logs
gcloud functions logs tail bgp-validator --region=$REGION

# Update function with new code
gcloud functions deploy bgp-validator \
  --source . \
  --runtime python39 \
  --trigger-http \
  --region=$REGION

# Delete function (for cleanup)
gcloud functions delete bgp-validator --region=$REGION
```

## 📊 Monitoring & Dashboard Commands

### **Metrics and Monitoring**
```bash
# List available metrics
gcloud logging metrics list

# Search for custom BGP metrics
gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=bgp-validator" --limit=10

# View custom metrics in Metrics Explorer
echo "🔗 Metrics Explorer: https://console.cloud.google.com/monitoring/metrics-explorer?project=$PROJECT_ID"

# Check monitoring quota and usage
gcloud logging describe-quota

# Create monitoring notification channel
gcloud alpha monitoring channels create \
  --display-name="BGP Security Alerts" \
  --type=email \
  --channel-labels=email_address=your-email@example.com
```

### **Dashboard Access Commands**
```bash
# Open BGP Security Dashboard
echo "📊 Dashboard URL: https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID"

# Create custom dashboard via gcloud (alternative to web console)
gcloud monitoring dashboards create --config-from-file=dashboard-config.json

# List existing dashboards
gcloud monitoring dashboards list --format="table(name,displayName)"

# Export dashboard configuration
gcloud monitoring dashboards describe [DASHBOARD_ID] > dashboard-backup.json
```

### **Generate Test Data for Dashboard**
```bash
# Get function URL for testing
FUNCTION_URL=$(gcloud functions describe bgp-validator --region=$REGION --format="value(httpsTrigger.url)")

# Generate diverse test scenarios
echo "📊 Generating dashboard test data..."

# Array of test routes
declare -a test_routes=(
  '{"prefix": "8.8.8.0/24", "origin_as": 15169, "as_path": [64512, 15169]}'
  '{"prefix": "1.1.1.0/24", "origin_as": 13335, "as_path": [64512, 13335]}'
  '{"prefix": "8.8.8.0/24", "origin_as": 666, "as_path": [64512, 666]}'
  '{"prefix": "203.0.113.0/24", "origin_as": 64496, "as_path": [64512, 64496, 64512]}'
  '{"prefix": "198.51.100.0/24", "origin_as": 65010, "as_path": [64512, 65001, 65002, 65003, 65004, 65005, 65006, 65007, 65008, 65009, 65010]}'
)

# Generate test data
for route in "${test_routes[@]}"; do
  echo "Testing: $(echo $route | jq -r .prefix)"
  result=$(curl -s -X POST $FUNCTION_URL \
    -H "Content-Type: application/json" \
    -d "$route")
  
  status=$(echo "$result" | jq -r '.validation_status')
  score=$(echo "$result" | jq -r '.security_score')
  threat=$(echo "$result" | jq -r '.threat_level')
  
  echo "  → Status: $status, Score: $score, Threat: $threat"
  sleep 5
done

echo "✅ Test data generated! Check dashboard in 2-3 minutes."
```

## 🔍 Debugging & Troubleshooting Commands

### **Function Debugging**
```bash
# View detailed function logs with timestamps
gcloud functions logs read bgp-validator \
  --region=$REGION \
  --limit=20 \
  --format="table(timestamp, textPayload)"

# Filter logs by severity
gcloud functions logs read bgp-validator \
  --region=$REGION \
  --filter="severity>=ERROR" \
  --limit=10

# View function configuration
gcloud functions describe bgp-validator \
  --region=$REGION \
  --format="yaml"

# Check function environment variables
gcloud functions describe bgp-validator \
  --region=$REGION \
  --format="value(environmentVariables)"

# Test function with curl and detailed output
curl -v -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"prefix": "8.8.8.0/24", "origin_as": 15169, "as_path": [64512, 15169]}'
```

### **Network and Connectivity Testing**
```bash
# Test RPKI validator connectivity
curl -s "https://rpki-validator.cloudflare.com/api/v1/origin/15169/8.8.8.0/24" | jq '.'

# Check DNS resolution
nslookup rpki-validator.cloudflare.com

# Test network connectivity from Cloud Shell
gcloud cloud-shell ssh --command="curl -s https://rpki-validator.cloudflare.com/api/v1/origin/15169/8.8.8.0/24"

# Check Cloud Function network settings
gcloud functions describe bgp-validator \
  --region=$REGION \
  --format="value(networkConfig)"
```

### **Metrics and Monitoring Debugging**
```bash
# Check if custom metrics are being created
gcloud logging read "resource.type=cloud_function AND textPayload:\"Metrics sent\"" --limit=5

# Verify Cloud Monitoring API is enabled
gcloud services list --enabled --filter="name:monitoring.googleapis.com"

# Check IAM permissions for monitoring
gcloud projects get-iam-policy $PROJECT_ID \
  --flatten="bindings[].members" \
  --filter="bindings.members:*cloudfunctions*" \
  --format="table(bindings.role,bindings.members)"

# Test custom metric creation manually
gcloud logging write "bgp-test-log" '{"message": "Test log entry", "severity": "INFO"}'
```

## 💰 Cost Management Commands

### **Budget and Billing**
```bash
# Check current project billing status
gcloud billing projects describe $PROJECT_ID

# List billing accounts
gcloud billing accounts list

# Check budget alerts (if configured)
gcloud billing budgets list --billing-account=$BILLING_ACCOUNT

# Estimate costs for Cloud Functions
gcloud functions describe bgp-validator \
  --region=$REGION \
  --format="value(sourceArchiveUrl,runtime,availableMemoryMb,timeout)"

# Check usage and quotas
gcloud compute project-info describe --format="table(quotas.metric,quotas.usage,quotas.limit)"
```

### **Resource Usage Monitoring**
```bash
# Check Cloud Function invocation count
gcloud functions logs read bgp-validator \
  --region=$REGION \
  --filter="textPayload:\"Function execution took\"" \
  --limit=10 \
  --format="table(timestamp,textPayload)"

# Monitor data transfer costs
gcloud logging read "resource.type=cloud_function" \
  --filter="textPayload:\"bytes\"" \
  --limit=5

# Check storage usage
gcloud alpha storage du gs://gcf-sources-* --summarize
```

## 🔄 CI/CD and Automation Commands

### **Git Integration**
```bash
# Initialize git repository
git init
git add .
git commit -m "Initial BGP Security project setup"

# Create .gitignore
cat > .gitignore << 'EOF'
# Python
__pycache__/
*.py[cod]
*$py.class
*.pyc
venv/
env/

# Terraform
*.tfstate
*.tfstate.*
.terraform/
.terraform.lock.hcl

# Google Cloud
.gcloudignore
service-account-key.json

# IDE
.vscode/
.idea/
*.swp
*.swo

# OS
.DS_Store
Thumbs.db

# Logs
*.log
logs/

# Environment files
.env
project-config.env
EOF

# Set up git hooks for automatic testing
mkdir -p .git/hooks
cat > .git/hooks/pre-commit << 'EOF'
#!/bin/bash
echo "Running pre-commit tests..."
cd src/cloud-functions/bgp-validator
python3 -m py_compile main.py
echo "✅ Syntax check passed"
EOF

chmod +x .git/hooks/pre-commit
```

### **Automated Deployment Scripts**
```bash
# Create deployment automation script
cat > deploy.sh << 'EOF'
#!/bin/bash
set -e

echo "🚀 Starting BGP Security deployment..."

# Load environment
source project-config.env

# Validate environment
if [ -z "$PROJECT_ID" ]; then
    echo "❌ PROJECT_ID not set"
    exit 1
fi

# Deploy function
echo "📦 Deploying Cloud Function..."
cd src/cloud-functions/bgp-validator
gcloud functions deploy bgp-validator \
  --runtime python39 \
  --trigger-http \
  --allow-unauthenticated \
  --entry-point bgp_validator \
  --memory 512MB \
  --timeout 60s \
  --project $PROJECT_ID \
  --region $REGION \
  --quiet

# Get function URL
FUNCTION_URL=$(gcloud functions describe bgp-validator --region=$REGION --format="value(httpsTrigger.url)")
echo "✅ Function deployed at: $FUNCTION_URL"

# Test deployment
echo "🧪 Testing deployment..."
curl -s -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"prefix": "8.8.8.0/24", "origin_as": 15169, "as_path": [64512, 15169]}' | jq -r '.validation_status'

echo "🎉 Deployment complete!"
EOF

chmod +x deploy.sh

# Create testing automation script
cat > test.sh << 'EOF'
#!/bin/bash
set -e

echo "🧪 Running BGP Security tests..."

# Load environment
source project-config.env

# Get function URL
FUNCTION_URL=$(gcloud functions describe bgp-validator --region=$REGION --format="value(httpsTrigger.url)")

# Test scenarios
echo "Testing valid route..."
curl -s -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"prefix": "8.8.8.0/24", "origin_as": 15169, "as_path": [64512, 15169]}' | jq -r '.validation_status'

echo "Testing malicious route..."
curl -s -X POST $FUNCTION_URL \
  -H "Content-Type: application/json" \
  -d '{"prefix": "8.8.8.0/24", "origin_as": 666, "as_path": [64512, 666]}' | jq -r '.validation_status'

echo "✅ All tests completed"
EOF

chmod +x test.sh
```

## 🔧 Maintenance Commands

### **Regular Maintenance**
```bash
# Update function dependencies
cd src/cloud-functions/bgp-validator
pip3 list --outdated
# Update requirements.txt with newer versions as needed

# Check function health
gcloud functions describe bgp-validator \
  --region=$REGION \
  --format="value(status,updateTime)"

# Review function logs for errors
gcloud functions logs read bgp-validator \
  --region=$REGION \
  --filter="severity>=WARNING" \
  --limit=20

# Check resource quotas
gcloud compute project-info describe \
  --format="table(quotas.metric,quotas.usage,quotas.limit)" \
  --filter="quotas.metric:(FUNCTIONS OR MONITORING)"
```

### **Performance Monitoring**
```bash
# Check function execution times
gcloud functions logs read bgp-validator \
  --region=$REGION \
  --filter="textPayload:\"Function execution took\"" \
  --limit=10

# Monitor error rates
gcloud functions logs read bgp-validator \
  --region=$REGION \
  --filter="severity>=ERROR" \
  --limit=10 \
  --format="table(timestamp,textPayload)"

# Check concurrent executions
gcloud functions describe bgp-validator \
  --region=$REGION \
  --format="value(serviceConfig.maxInstanceCount,serviceConfig.availableMemoryMb)"
```

### **Security Auditing**
```bash
# Review IAM permissions
gcloud projects get-iam-policy $PROJECT_ID \
  --format="table(bindings.role,bindings.members)" \
  --flatten="bindings[].members"

# Check function security settings
gcloud functions describe bgp-validator \
  --region=$REGION \
  --format="value(httpsPolicy,ingressSettings)"

# Audit API access
gcloud logging read "protoPayload.serviceName=cloudfunctions.googleapis.com" \
  --limit=10 \
  --format="table(timestamp,protoPayload.methodName,protoPayload.authenticationInfo.principalEmail)"

# Check for unusual function invocations
gcloud functions logs read bgp-validator \
  --region=$REGION \
  --filter="timestamp>=\"$(date -d '1 hour ago' --iso-8601)\"" \
  --format="table(timestamp,httpRequest.remoteIp,httpRequest.userAgent)"
```

## 📋 Quick Reference

### **Essential Daily Commands**
```bash
# Load environment
source setup-env.sh

# Check function status
gcloud functions describe bgp-validator --region=$REGION --format="value(status)"

# View recent logs
gcloud functions logs read bgp-validator --region=$REGION --limit=5

# Test function
curl -s -X POST $(gcloud functions describe bgp-validator --region=$REGION --format="value(httpsTrigger.url)") \
  -H "Content-Type: application/json" \
  -d '{"prefix": "8.8.8.0/24", "origin_as": 15169, "as_path": [64512, 15169]}' | jq '.validation_status'

# Check dashboard
echo "📊 Dashboard: https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID"
```

### **Emergency Commands**
```bash
# Stop function (delete)
gcloud functions delete bgp-validator --region=$REGION --quiet

# Emergency redeploy
./deploy.sh

# Check billing alerts
gcloud billing budgets list --billing-account=$BILLING_ACCOUNT

# Contact information for critical issues
echo "📞 Emergency contacts and escalation procedures should be documented here"
```

This comprehensive command reference provides all the Linux/bash commands needed to deploy, manage, monitor, and troubleshoot the BGP Security project.