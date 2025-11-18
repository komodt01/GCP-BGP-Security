What This Project Is:

This project builds a secure monitoring and governance
foundation in Google Cloud. It focuses on visibility,
access control, threat detection, and protection of
sensitive data. The design uses native GCP services to
collect logs, enforce least privilege, scan for sensitive
data, and alert on high-risk activity.

How It Works:

1. Identity and Access:
   IAM roles are restricted using least-privilege
   principles. Service accounts are created with only the
   permissions needed for each function. IAM activity is
   tracked through Audit Logs.

2. Logging and Monitoring:
   Cloud Logging collects audit, admin, data access, and
   system logs from all resources. Monitoring converts key
   events into alerts. Logs are retained for compliance and
   forensic analysis.

3. Network Security:
   VPC Firewall Rules enforce controlled access. SSH and
   RDP access is restricted. Private IP paths are used
   where possible to limit exposure.

4. Data Protection:
   Cloud KMS provides encryption for data at rest. Secret
   Manager stores credentials securely. Cloud DLP scans
   buckets and datasets to identify sensitive data such as
   PII.

5. Asset Governance:
   Cloud Asset Inventory tracks all resources and
   configuration changes. This supports compliance,
   auditing, and drift detection.

6. Automation and Response:
   Optional Cloud Functions can react to events such as
   privilege escalation, firewall changes, or sensitive
   data findings. Alerts can be sent to email or chat
   systems.

Overall Flow:

Resources generate logs.
Logs are sent to Cloud Logging.
Monitoring creates alerts from these logs.
IAM controls limit access.
DLP identifies sensitive data.
Firewall rules protect the network.
Asset Inventory maintains visibility.

The result is a secure, monitored, and well-governed
environment that aligns with industry security standards.
