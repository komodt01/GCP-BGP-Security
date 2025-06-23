# Technologies Deep Dive
*Technical explanation of BGP security technologies and implementation*

## 🌐 BGP (Border Gateway Protocol) Fundamentals

### **What is BGP?**
BGP is the **routing protocol of the internet** that determines how data packets travel between different networks (Autonomous Systems). It's essentially the "GPS of the internet" that decides the best path for your data to reach its destination.

### **How BGP Works**
```
Internet Service Provider A ←→ BGP ←→ Internet Service Provider B
        ↓                                    ↓
   Your Company                        Remote Server
```

1. **Autonomous Systems (AS)**: Each network has a unique AS Number (ASN)
2. **Route Announcements**: Networks announce which IP prefixes they can reach
3. **Path Selection**: BGP chooses the best path based on various criteria
4. **Route Propagation**: Path information spreads across the internet

### **BGP Security Challenges**
- **No built-in authentication** - anyone can announce any route
- **Trust-based system** - networks trust their neighbors' announcements
- **Global impact** - a single bad announcement can affect worldwide connectivity
- **Difficult to detect** - malicious routes can look legitimate

## 🔒 RPKI (Resource Public Key Infrastructure)

### **What is RPKI?**
RPKI is a **cryptographic security framework** that allows network operators to prove they have the right to announce specific IP address ranges. Think of it as a "digital certificate" for network routes.

### **How RPKI Works**
```
Regional Internet Registry (RIR)
        ↓ (issues certificate)
Network Operator
        ↓ (creates ROA)
Route Origin Authorization (ROA)
        ↓ (validates against)
BGP Route Announcement
```

**Key Components:**
- **ROA (Route Origin Authorization)**: Digital certificate saying "AS X is authorized to announce prefix Y"
- **RPKI Validator**: Service that checks if routes match their ROAs
- **Validation Status**: 
  - `Valid` - Route matches a ROA
  - `Invalid` - Route contradicts a ROA (potential hijacking)
  - `Not Found` - No ROA exists for this route

### **RPKI in Our System**
```python
# Example RPKI validation
url = f"https://rpki-validator.cloudflare.com/api/v1/origin/{origin_as}/{prefix}"
response = requests.get(url, timeout=5)
rpki_data = response.json()

if rpki_data['status'] == 'valid':
    return {'score': 100, 'threat': 'low'}
elif rpki_data['status'] == 'invalid':
    return {'score': 0, 'threat': 'critical'}  # Potential hijacking!
```

## 🎯 AS Path Analysis

### **What are AS Paths?**
An AS path is the **sequence of networks** a route advertisement has traveled through. It's like a "passport stamp" showing every country (network) your data packet will visit.

### **AS Path Structure**
```
Route: 8.8.8.0/24 via AS Path [64512, 15169]
Meaning: "To reach Google's 8.8.8.0/24, go through AS 64512, then AS 15169 (Google)"
```

### **Security Validations We Perform**

#### **1. AS Path Loop Detection**
```python
# Detect if an AS appears multiple times (loop)
if len(as_path) != len(set(as_path)):
    return {'threat': 'critical', 'reason': 'AS path loop detected'}
```

#### **2. Path Length Analysis**
```python
# Unusually long paths may indicate attack or misconfiguration
if len(as_path) > 20:
    return {'threat': 'high', 'reason': 'Extremely long AS path'}
```

#### **3. Malicious ASN Detection**
```python
# Check against known malicious AS numbers
malicious_asns = {666, 1337, 31337}
if any(asn in malicious_asns for asn in as_path):
    return {'threat': 'critical', 'reason': 'Malicious ASN detected'}
```

#### **4. Private ASN in Public Routes**
```python
# Private ASNs should not appear in public internet routes
private_asns = [asn for asn in as_path if 64512 <= asn <= 65534]
if private_asns:
    return {'threat': 'medium', 'reason': 'Private ASN in public route'}
```

## ☁️ Google Cloud Platform Technologies

### **Google Cloud Functions**
**Serverless compute** platform that runs our BGP validator code.

**Why Cloud Functions?**
- **Auto-scaling**: Handles traffic spikes automatically
- **Pay-per-use**: Only pay when validating routes
- **Fast startup**: <100ms cold start for rapid response
- **No infrastructure**: No servers to manage or maintain

**Architecture:**
```
HTTP Request → Cloud Function → BGP Validation → JSON Response
     ↓
Cloud Monitoring (metrics)
```

### **Cloud Monitoring**
**Metrics collection and visualization** service for our security dashboard.

**Custom Metrics We Create:**
```python
# Security score metric
series.metric.type = "custom.googleapis.com/bgp/security_score"
point.value = {"double_value": float(security_score)}

# Threat level metric  
series.metric.type = "custom.googleapis.com/bgp/threat_level"
point.value = {"int64_value": threat_level_numeric}

# Validation count metric
series.metric.type = "custom.googleapis.com/bgp/validation_count"
point.value = {"int64_value": 1}
```

**Dashboard Widgets:**
- **Scorecard**: Current security posture (0-100 score)
- **Line Chart**: Security trends over time
- **Stacked Area**: Threat level distribution
- **Bar Chart**: Validation results (passed/warning/failed)

### **BigQuery (Future Enhancement)**
**Data warehouse** for long-term security analytics and threat intelligence.

**Potential Use Cases:**
```sql
-- Find patterns in attack attempts
SELECT origin_as, COUNT(*) as attack_count
FROM bgp_validations 
WHERE validation_status = 'failed'
  AND threat_level = 'critical'
GROUP BY origin_as
ORDER BY attack_count DESC;

-- Analyze security trends
SELECT DATE(timestamp) as date,
       AVG(security_score) as avg_security_score
FROM bgp_validations
GROUP BY date
ORDER BY date;
```

## 🔧 Implementation Technologies

### **Python & Libraries**

#### **Core Libraries:**
```python
import requests          # RPKI API calls
import json             # Data handling
import time             # Timestamps
import logging          # System logging
from google.cloud import monitoring_v3  # Metrics
```

#### **Key Design Patterns:**

**1. Modular Validation Architecture**
```python
class GCPBGPValidator:
    def validate_route(self, route_data):
        checks = [
            self._validate_as_path(route_data.get('as_path')),
            self._validate_rpki(route_data.get('prefix'), route_data.get('origin_as')),
            self._validate_prefix(route_data.get('prefix')),
            self._validate_geography(route_data)
        ]
        return self._calculate_security_score(checks)
```

**2. Weighted Security Scoring**
```python
def _calculate_security_score(self, check_results):
    weights = {
        'as_path': 0.4,    # 40% - Critical for route legitimacy
        'rpki': 0.4,       # 40% - Critical for authenticity  
        'prefix': 0.15,    # 15% - Format validation
        'geography': 0.05  # 5% - Future enhancement
    }
    
    total_score = sum(result['score'] * weight for result, weight in zip(check_results, weights.values()))
    return min(100, int(total_score))
```

**3. Graceful Error Handling**
```python
def _validate_rpki(self, prefix, origin_as):
    try:
        response = requests.get(rpki_url, timeout=5)
        return self._process_rpki_response(response)
    except requests.exceptions.Timeout:
        # Don't fail validation due to external service timeout
        return {'passed': True, 'score': 50, 'reason': 'RPKI service timeout'}
    except Exception as e:
        # Log error but continue validation
        logger.warning(f"RPKI validation failed: {str(e)}")
        return {'passed': True, 'score': 50, 'reason': 'RPKI validation error'}
```

### **Infrastructure as Code (Terraform)**

**Why Terraform?**
- **Reproducible deployments** across environments
- **Version control** for infrastructure changes
- **State management** for resource tracking
- **Multi-cloud support** for future AWS implementation

**Key Resources:**
```hcl
# Cloud Function for BGP validation
resource "google_cloudfunctions_function" "bgp_validator" {
  name        = "bgp-validator"
  runtime     = "python39"
  entry_point = "bgp_validator"
  trigger {
    http_trigger {}
  }
}

# Custom monitoring metrics
resource "google_monitoring_metric_descriptor" "bgp_security_score" {
  type         = "custom.googleapis.com/bgp/security_score"
  metric_kind  = "GAUGE"
  value_type   = "DOUBLE"
  description  = "BGP route security score (0-100)"
}
```

## 🔍 Security Validation Algorithm

### **Multi-Layer Security Model**
Our system implements **defense in depth** with multiple validation layers:

```
Input Route → AS Path Check → RPKI Check → Prefix Check → Geography Check → Security Score
     ↓              ↓             ↓            ↓              ↓              ↓
   Route Data   Malicious ASN   Invalid ROA   Bad Format   Geo Anomaly   0-100 Score
```

### **Threat Level Classification**
```python
def _determine_threat_level(self, security_score):
    if security_score >= 90:   return 'low'      # Green: Safe routes
    elif security_score >= 75: return 'medium'   # Yellow: Needs attention  
    elif security_score >= 50: return 'high'     # Orange: Suspicious
    else:                      return 'critical' # Red: Likely attack
```

### **Decision Matrix**
| Validation Check | Weight | Pass Score | Fail Score | Impact |
|------------------|--------|------------|------------|---------|
| AS Path Valid | 40% | 100 | 0 | Route legitimacy |
| RPKI Valid | 40% | 100 | 0 | Cryptographic proof |
| Prefix Format | 15% | 100 | 0 | Basic validation |
| Geography | 5% | 90 | 50 | Consistency check |

## 📊 Monitoring & Observability

### **Metrics Architecture**
```
BGP Validator → Cloud Monitoring → Dashboard Widgets
     ↓               ↓                    ↓
  Custom Metrics   Time Series      Visual Charts
```

### **Key Performance Indicators (KPIs)**
- **Security Score**: Real-time threat assessment (0-100)
- **Threat Level**: Categorical risk classification (Low/Medium/High/Critical)
- **Validation Rate**: Routes processed per second
- **Detection Accuracy**: True positive rate for threats
- **Response Time**: End-to-end validation latency

### **Alerting Strategy**
```python
# Critical threat detection
if security_score < 50:
    send_alert({
        'severity': 'HIGH',
        'message': 'Critical BGP threat detected',
        'route': route_data,
        'score': security_score
    })
```

## 🔄 Data Flow Architecture

### **Real-Time Processing Pipeline**
```
1. BGP Route Input → 2. Cloud Function → 3. Validation Engine → 4. Security Scoring
                                ↓                               ↓
                        5. RPKI API Call                6. Metrics Export
                                ↓                               ↓
                        7. External Validation         8. Dashboard Update
```

### **Scalability Design**
- **Horizontal scaling**: Cloud Functions auto-scale based on demand
- **Caching strategy**: RPKI results cached to reduce external API calls
- **Async processing**: Non-blocking validation for high throughput
- **Error isolation**: One validation failure doesn't affect others

## 🛡️ Security Architecture Principles

### **1. Defense in Depth**
Multiple validation layers ensure comprehensive threat detection even if one layer fails.

### **2. Fail-Safe Design** 
External service failures (like RPKI timeouts) don't crash the validation process.

### **3. Zero Trust**
Every route is validated regardless of source - no implicit trust.

### **4. Continuous Monitoring**
Real-time metrics provide immediate visibility into security posture.

### **5. Audit Trail**
All validation decisions are logged for forensic analysis and compliance.

This technical architecture demonstrates enterprise-grade security engineering with cloud-native scalability and operational excellence.