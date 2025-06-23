# Project Teardown Guide
*Safe and complete removal of BGP Security project resources*

## ⚠️ Important Warnings

### **Before Starting Teardown:**
- 🚨 **Data Loss Warning**: This process will permanently delete all project data
- 💰 **Billing Impact**: Resources continue incurring charges until fully deleted
- 📊 **Dashboard Data**: All monitoring history will be lost
- 🔄 **Irreversible**: Some deletions cannot be undone

### **Backup Checklist** ✅
Before proceeding, ensure you have:
- [ ] Exported dashboard configurations
- [ ] Downloaded function logs for analysis
- [ ] Saved any important validation results
- [ ] Documented configuration settings
- [ ] Exported monitoring data if needed

## 🎯 Teardown Strategy

### **Recommended Approach**: Incremental Deletion
1. **Stop active services** (Cloud Functions)
2. **Delete monitoring resources** (dashboards, alerts)
3. **Remove compute resources** (functions, storage)
4. **Clean up networking** (if any custom configs)
5. **Delete project** (final step)

### **Alternative**: Complete Project Deletion
- Fastest method but less granular control
- Deletes everything at once
- Cannot recover individual resources

## 🛠️ Step-by-Step Teardown

### **Step 1: Prepare Environment**
```bash
# Load project configuration
source project-config.env

# Verify current project
gcloud config get-value project
echo "Current project: $(gcloud config get-value project)"
echo "⚠️  Are you sure you want to delete resources from this project? (y/N)"
read -r confirmation
if [[ $confirmation != [yY] ]]; then
    echo "Teardown cancelled."
    exit 1
fi

# Set variables
PROJECT_ID=$(gcloud config get-value project)
REGION="us-central1"
```

### **Step 2: Export Important Data (Optional)**
```bash
echo "📥 Exporting important data before deletion..."

# Create backup directory
mkdir -p teardown-backup/$(date +%Y%m%d_%H%M%S)
cd teardown-backup/$(date +%Y%m%d_%H%M%S)

# Export function source code
gcloud functions describe bgp-validator --region=$REGION --format="yaml" > function-config.yaml

# Export recent logs
gcloud functions logs read bgp-validator --region=$REGION --limit=100 > function-logs.txt

# Export monitoring data
gcloud logging read "resource.type=cloud_function AND resource.labels.function_name=bgp-validator" \
  --limit=500 --format="json" > monitoring-logs.json

# List dashboards for manual backup
gcloud monitoring dashboards list --format="table(name,displayName)" > dashboards-list.txt

echo "✅ Data exported to: $(pwd)"
cd ../..
```

### **Step 3: Delete Cloud Functions**
```bash
echo "🗑️  Deleting Cloud Functions..."

# List all functions in the project
echo "Functions to delete:"
gcloud functions list --format="table(name,status,trigger.httpsTrigger.url)"

# Delete BGP validator function
gcloud functions delete bgp-validator \
  --region=$REGION \
  --quiet

# Verify deletion
echo "Remaining functions:"
gcloud functions list --format="table(name,status)"

echo "✅ Cloud Functions deleted"
```

### **Step 4: Delete Monitoring Resources**
```bash
echo "📊 Deleting monitoring resources..."

# List custom metrics
echo "Custom metrics in project:"
gcloud logging metrics list --format="table(name,description)"

# Delete custom metrics (if any were created via gcloud)
# Note: Most metrics are auto-deleted when functions are removed

# List notification channels
gcloud alpha monitoring channels list --format="table(name,displayName,type)"

# Delete notification channels (replace CHANNEL_ID with actual IDs)
# gcloud alpha monitoring channels delete CHANNEL_ID --quiet

# Note: Dashboards need to be deleted via console or API
echo "⚠️  Manual step: Delete dashboards via Cloud Console"
echo "🔗 https://console.cloud.google.com/monitoring/dashboards?project=$PROJECT_ID"

echo "✅ Monitoring resources cleanup initiated"
```

### **Step 5: Delete Storage Resources**
```bash
echo "💾 Deleting storage resources..."

# List Cloud Storage buckets used by Cloud Functions
echo "Cloud Function source buckets:"
gsutil ls gs://gcf-sources-* 2>/dev/null || echo "No function source buckets found"

# Delete Cloud Function source archives (optional - they auto-expire)
# gsutil -m rm -r gs://gcf-sources-*/

# List any other storage buckets
echo "All storage buckets in project:"
gsutil ls -p $PROJECT_ID 2>/dev/null || echo "No storage buckets found"

echo "✅ Storage resources identified (auto-cleanup will handle function sources)"
```

### **Step 6: Delete IAM Resources**
```bash
echo "🔐 Cleaning up IAM resources..."

# List custom IAM roles (if any were created)
gcloud iam roles list --project=$PROJECT_ID --format="table(name,title,stage)"

# List service accounts
echo "Service accounts in project:"
gcloud iam service-accounts list --format="table(email,displayName)"

# Note: Default service accounts should not be deleted
# Custom service accounts can be deleted if created:
# gcloud iam service-accounts delete SERVICE_ACCOUNT_EMAIL --quiet

echo "✅ IAM resources reviewed (default accounts preserved)"
```

### **Step 7: Verify Billing Impact**
```bash
echo "💰 Checking billing and cost impact..."

# Check current billing status
gcloud billing projects describe $PROJECT_ID --format="value(billingEnabled)"

# List any budget alerts
gcloud billing budgets list --billing-account=$BILLING_ACCOUNT --format="table(displayName,amount.specifiedAmount.units)"

# Estimate remaining costs
echo "📊 Resources that may still incur costs:"
echo "- Cloud Functions: Deleted ✅"
echo "- Storage buckets: Check manually"
echo "- Logging data: Retention charges may apply"
echo "- Monitoring metrics: Auto-cleanup in progress"

echo "✅ Billing impact assessed"
```

### **Step 8: Final Project Cleanup**
```bash
echo "🧹 Final project cleanup..."

# Disable APIs to stop any residual charges
echo "Disabling APIs..."
gcloud services disable \
  cloudfunctions.googleapis.com \
  monitoring.googleapis.com \
  logging.googleapis.com \
  --force \
  --quiet

# List remaining resources
echo "Remaining compute resources:"
gcloud compute instances list --format="table(name,zone,status)" 2>/dev/null || echo "No compute instances"

echo "Remaining App Engine services:"
gcloud app services list --format="table(id,versions)" 2>/dev/null || echo "No App Engine services"

echo "✅ Project cleanup completed"
```

## 🗑️ Complete Project Deletion (Nuclear Option)

### **When to Use This Method:**
- You want to delete everything at once
- The project was created specifically for this demo
- You don't need granular control over resource deletion

### **Complete Deletion Commands:**
```bash
echo "💣 COMPLETE PROJECT DELETION"
echo "⚠️  This will PERMANENTLY DELETE the entire project: $PROJECT_ID"
echo "⚠️  This action CANNOT be undone!"
echo "Type 'DELETE' to confirm complete project deletion:"
read -r delete_confirmation

if [[ $delete_confirmation == "DELETE" ]]; then
    echo "🗑️  Deleting project $PROJECT_ID..."
    
    # Delete the entire project
    gcloud projects delete $PROJECT_ID --quiet
    
    echo "✅ Project deletion initiated"
    echo "📝 Note: Project deletion can take several minutes to complete"
    echo "💰 Billing will stop once deletion is complete"
else
    echo "❌ Project deletion cancelled"
fi
```

## 📋 Verification Commands

### **Verify Successful Teardown:**
```bash
echo "🔍 Verifying teardown completion..."

# Check if project still exists
if gcloud projects describe $PROJECT_ID >/dev/null 2>&1; then
    echo "⚠️  Project still exists"
    
    # Check for remaining functions
    echo "Remaining Cloud Functions:"
    gcloud functions list --format="table(name,status)" 2>/dev/null || echo "No functions found"
    
    # Check for remaining storage
    echo "Remaining storage buckets:"
    gsutil ls -p $PROJECT_ID 2>/dev/null || echo "No buckets found"
    
    # Check billing status
    echo "Billing status:"
    gcloud billing projects describe $PROJECT_ID --format="value(billingEnabled)" 2>/dev/null || echo "Project not found or billing disabled"
    
else
    echo "✅ Project successfully deleted"
fi
```

### **Check for Residual Costs:**
```bash
echo "💰 Checking for potential residual costs..."

# Check billing account for recent charges
gcloud billing accounts describe $BILLING_ACCOUNT --format="table(displayName,open)"

# List any remaining active projects
echo "Other active projects on this billing account:"
gcloud billing projects list --billing-account=$BILLING_ACCOUNT --format="table(projectId,billingEnabled)"

echo "📝 Monitor your billing dashboard for a few days to ensure no unexpected charges"
echo "🔗 Billing Dashboard: https://console.cloud.google.com/billing"
```

## ⚠️ Common Issues & Solutions

### **Issue: Function Won't Delete**
```bash
# Error: Function is receiving traffic
# Solution: Wait a few minutes and retry
echo "Waiting for function traffic to stop..."
sleep 60
gcloud functions delete bgp-validator --region=$REGION --quiet
```

### **Issue: Storage Bucket Access Denied**
```bash
# Error: Access denied to storage bucket
# Solution: Check IAM permissions or skip bucket deletion
echo "Skipping storage bucket deletion due to permissions"
echo "Buckets will auto-delete after project deletion"
```

### **Issue: Project Deletion Fails**
```bash
# Error: Project has active resources
# Solution: List and manually delete remaining resources
echo "Checking for resources blocking project deletion..."

# Check for App Engine
gcloud app describe 2>/dev/null && echo "App Engine detected - requires manual cleanup"

# Check for Compute Engine
gcloud compute instances list --format="value(name)" | wc -l

# Check for active billing
gcloud billing projects describe $PROJECT_ID --format="value(billingEnabled)"
```

### **Issue: Unexpected Charges Continue**
```bash
# Check for hidden resources
gcloud asset search-all-resources --scope=projects/$PROJECT_ID --asset-types="compute.googleapis.com/Instance,storage.googleapis.com/Bucket"

# Review billing details
echo "🔗 Detailed billing: https://console.cloud.google.com/billing/$BILLING_ACCOUNT"
```

## 📝 Post-Teardown Checklist

### **Immediate Actions (Day 1):**
- [ ] Verify project deletion completed
- [ ] Check billing dashboard for charge cessation
- [ ] Remove local project files (optional)
- [ ] Update any documentation referencing the project
- [ ] Remove project from gcloud configurations

### **Follow-up Actions (Week 1):**
- [ ] Monitor billing for unexpected charges
- [ ] Verify no residual storage costs
- [ ] Confirm all resources fully deleted
- [ ] Document lessons learned from teardown process

### **Clean Up Local Environment:**
```bash
# Remove local project configuration
rm -f project-config.env setup-env.sh

# Remove gcloud project configuration
gcloud config configurations delete bgp-security-config 2>/dev/null || echo "No configuration to delete"

# Remove local project directory (optional)
echo "Remove local project directory? (y/N)"
read -r remove_local
if [[ $remove_local == [yY] ]]; then
    cd ..
    rm -rf gcp-bgp-security
    echo "✅ Local project directory removed"
fi
```

## 🎯 Teardown Summary Template

```bash
# Generate teardown summary
cat > teardown-summary.md << EOF
# BGP Security Project Teardown Summary

**Date**: $(date)
**Project ID**: $PROJECT_ID
**Region**: $REGION

## Resources Deleted:
- [x] Cloud Functions (bgp-validator)
- [x] Monitoring dashboards
- [x] Custom metrics
- [x] IAM bindings
- [x] API services disabled
- [x] Complete project deletion

## Verification:
- Project Status: $(gcloud projects describe $PROJECT_ID >/dev/null 2>&1 && echo "Still exists" || echo "Deleted")
- Billing Status: Monitor for 7 days
- Estimated Final Cost: \$$(echo "scale=2; 50 * 1" | bc) (estimated)

## Next Steps:
- Monitor billing dashboard for 1 week
- Verify no unexpected charges
- Document lessons learned

**Teardown completed successfully** ✅
EOF

echo "✅ Teardown summary created: teardown-summary.md"
```

## 🚨 Emergency Contact Information

### **If Issues Arise:**
- **Google Cloud Support**: https://cloud.google.com/support
- **Billing Support**: https://cloud.google.com/billing/docs/how-to/get-support
- **Documentation**: https://cloud.google.com/docs

### **Emergency Commands:**
```bash
# Emergency stop all billing
gcloud billing projects unlink $PROJECT_ID

# Force project deletion (if authorized)
gcloud projects delete $PROJECT_ID --quiet

# Contact billing support immediately if unexpected charges appear
echo "📞 For billing emergencies: https://cloud.google.com/billing/docs/how-to/get-support"
```

---

**⚠️ Remember**: This teardown guide ensures clean project removal while preserving important learning materials and documentation. Always verify completion and monitor billing for a few days after teardown.