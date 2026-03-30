# FinOps & Security Best Practices Guide

## 💰 Cost Optimization (FinOps)

### Current Configuration Costs (Monthly Estimate - us-east-1)

| Component | Configuration | Monthly Cost | Notes |
|-----------|--------------|--------------|-------|
| **EKS Control Plane** | 1 cluster | $72.00 | Fixed cost, cannot be reduced |
| **EC2 Instances** | 2x t3.medium | ~$60.00 | On-Demand pricing |
| **NAT Gateway** | 1x (single) | ~$32.00 | $0.045/hour |
| **NAT Data Transfer** | Variable | ~$5-20 | $0.045/GB processed |
| **EBS Volumes** | 2x 20GB gp3 | ~$3.20 | $0.08/GB-month |
| **KMS Key** | 1 key | ~$1.00 | $1/month + usage |
| **CloudWatch Logs** | All log types | ~$2-10 | Volume dependent |
| **VPC Flow Logs** | Enabled | ~$1-5 | Traffic dependent |
| **Total** | - | **$176-203** | **Default configuration** |

### Development/Test Environment Optimization

Save **~$100-121/month (57% reduction)** with these changes:

```hcl
# terraform.tfvars - DEV OPTIMIZED
environment  = "dev"

# 1. Disable NAT Gateway (use only for testing without internet from private subnets)
enable_nat_gateway = false  # Save $32-52/month

# 2. Enable Spot Instances (60-90% discount, but can be interrupted)
enable_spot_instances = true  # Save $36/month

# 3. Reduce log retention
cloudwatch_log_group_retention_days = 1  # Save $1-3/month

# 4. Minimal logging (keep 'api' and 'audit' for security)
cluster_enabled_log_types = ["api", "audit"]  # Save $1-5/month

# 5. Scale down to minimum
eks_min_size         = 1
eks_desired_capacity = 1  # Save $30/month
eks_max_size         = 2

# ESTIMATED DEV COST: $75-82/month
```

### Production Environment Optimization

Maintain security while optimizing costs:

```hcl
# terraform.tfvars - PRODUCTION OPTIMIZED
environment  = "production"

# 1. Single NAT Gateway (acceptable for small prod workloads)
single_nat_gateway = true  # Save $32/month vs multi-AZ

# 2. Use cheaper instance types with same performance
eks_instance_types = ["t3a.medium", "t3a.large"]  # Save 10% vs t3

# 3. Reasonable log retention
cloudwatch_log_group_retention_days = 30  # Balance cost vs compliance

# 4. Enable auto-scaling
eks_min_size         = 2  # For HA
eks_desired_capacity = 2
eks_max_size         = 5

# 5. Consider Savings Plans
# Purchase 1-year Compute Savings Plan for 20-40% discount
```

### Advanced Cost Reduction Strategies

#### 1. Scheduled Scaling (Non-Production)
```bash
# Scale down cluster during off-hours
# Monday-Friday: Scale down at 7 PM, scale up at 7 AM
# Saturday-Sunday: Scale down completely

# Using AWS Instance Scheduler or Lambda
# Potential savings: 30-50% on EC2 costs
```

#### 2. Kubernetes Cluster Autoscaler
```yaml
# Already configured in the infrastructure
# Automatically scales nodes based on pod requirements
# Prevents over-provisioning
```

#### 3. Right-Sizing
```bash
# Monitor actual resource usage
kubectl top nodes
kubectl top pods --all-namespaces

# Adjust instance types based on actual usage:
# Low CPU/Memory: t3.small or t3a.small
# Medium: t3.medium or t3a.medium
# High: t3.large or t3a.large
```

#### 4. Reserved Capacity & Savings Plans
- **1-year Commitment**: 20-40% savings
- **3-year Commitment**: 40-60% savings
- Use for stable, predictable workloads

### Cost Monitoring & Alerting

#### Enable AWS Cost Explorer
```bash
# View costs by:
# - Service (EKS, EC2, NAT Gateway)
# - Tag (Environment, Project, CostCenter)
# - Time period (Daily, Monthly)
```

#### Set Up AWS Budgets
```bash
# Create budget alerts:
# - Monthly budget: $200
# - Alert at 80% ($160)
# - Alert at 100% ($200)
# - Alert at 120% ($240)
```

#### Cost Allocation Tags
```hcl
# Already implemented in default_tags
additional_tags = {
  Environment = "dev"
  Project     = "cloudkube-eks"
  CostCenter  = "Engineering"
  Owner       = "DevOps Team"
}
```

## 🔐 Security Best Practices

### Network Security

#### ✅ Implemented Security Controls

1. **Private Subnets for Worker Nodes**
   - All EKS worker nodes run in private subnets
   - No direct internet access
   - Outbound traffic via NAT Gateway

2. **VPC Flow Logs**
   - Enabled by default
   - Captures all network traffic
   - Stored in CloudWatch Logs
   - Useful for security analysis and troubleshooting

3. **Security Groups**
   - Least privilege access
   - Separate security groups for control plane and nodes
   - Only required ports open
   - Documented rules with descriptions

4. **Network ACLs**
   - Additional layer of defense
   - Stateless firewall at subnet level
   - Allow all by default (customize as needed)

#### 🔒 Recommended Actions

```hcl
# 1. Restrict API endpoint access to your IP/VPN
cluster_endpoint_public_access_cidrs = ["YOUR-IP/32"]

# 2. For maximum security, disable public endpoint
cluster_endpoint_public_access = false

# 3. Customize Network ACL rules for specific requirements
# Edit infra/modules/vpc/main.tf - aws_network_acl resource
```

### Data Protection

#### ✅ Implemented Security Controls

1. **KMS Encryption for EKS Secrets**
   - Automatic key rotation enabled
   - 30-day deletion window for recovery
   - All Kubernetes secrets encrypted at rest

2. **Encrypted CloudWatch Logs**
   - Control plane logs encrypted
   - VPC Flow Logs encrypted

3. **HTTPS Only**
   - All API communications over TLS
   - Certificate-based authentication

#### 🔒 Recommended Actions

```bash
# 1. Enable encryption for EBS volumes (add to node group)
# 2. Use AWS Secrets Manager for application secrets
# 3. Implement Pod Security Standards
# 4. Enable AWS GuardDuty for threat detection (~$5-10/month)
```

### Access Control

#### ✅ Implemented Security Controls

1. **IRSA (IAM Roles for Service Accounts)**
   - Pod-level IAM permissions
   - No need for instance-level credentials
   - EBS CSI Driver already configured with IRSA

2. **No SSH Keys by Default**
   - SSH access disabled unless explicitly configured
   - Use AWS Systems Manager Session Manager instead

3. **SSM Access for Worker Nodes**
   - Secure shell access via Systems Manager
   - No need to expose SSH ports
   - Full audit trail in CloudTrail

4. **Least Privilege IAM Roles**
   - Cluster role: Only required EKS permissions
   - Node role: Worker node permissions + SSM
   - Separate roles for different functions

#### 🔒 Recommended Actions

```bash
# 1. Configure kubectl access with IAM authentication
aws eks update-kubeconfig --region us-east-1 --name cloudkube-eks-dev

# 2. Implement Kubernetes RBAC
kubectl create rolebinding developers --clusterrole=edit --group=developers

# 3. Use AWS IAM Identity Center for centralized access
# 4. Enable MFA for all IAM users
# 5. Rotate credentials regularly
```

### Audit & Compliance

#### ✅ Implemented Security Controls

1. **Control Plane Logging**
   - All 5 log types enabled:
     - API server logs
     - Audit logs
     - Authenticator logs
     - Controller manager logs
     - Scheduler logs

2. **Resource Tagging**
   - Automatic tagging via provider
   - Environment, Project, ManagedBy tags
   - Custom tags for cost allocation

3. **Automated Security Scanning**
   - tfsec in CI/CD pipeline
   - SARIF reports uploaded to GitHub Security
   - Blocks on critical security issues

#### 🔒 Recommended Actions

```bash
# 1. Enable AWS CloudTrail for API audit trail
# 2. Enable AWS Config for compliance tracking
# 3. Implement AWS Security Hub for centralized security view
# 4. Set up CloudWatch alarms for security events
# 5. Regular security reviews and penetration testing
```

### Application Security

#### 🔒 Recommended Actions

```yaml
# 1. Implement Pod Security Standards (PSS)
apiVersion: v1
kind: Namespace
metadata:
  name: production
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted

# 2. Network Policies for pod-to-pod traffic control
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: deny-all
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  - Egress

# 3. Resource Quotas and Limit Ranges
apiVersion: v1
kind: ResourceQuota
metadata:
  name: compute-quota
spec:
  hard:
    requests.cpu: "10"
    requests.memory: "20Gi"
    limits.cpu: "20"
    limits.memory: "40Gi"

# 4. Use image scanning (Amazon ECR scanning)
# 5. Implement OPA/Gatekeeper for policy enforcement
# 6. Regular dependency scanning with Trivy or Snyk
```

## 📊 Security & Cost Monitoring

### CloudWatch Dashboards

Create custom dashboards to monitor:
- EKS cluster health
- Node resource utilization
- Pod metrics
- Network traffic
- Cost trends

### Recommended Alarms

```hcl
# CloudWatch Alarms to create:
1. High CPU utilization (> 80%)
2. High memory utilization (> 80%)
3. Failed pod deployments
4. Unauthorized API calls
5. Budget threshold exceeded
6. NAT Gateway errors
7. VPC Flow Log failures
```

### Regular Security Reviews

**Weekly:**
- Review CloudWatch Logs for anomalies
- Check pod security posture
- Monitor resource usage

**Monthly:**
- Review IAM permissions
- Analyze cost trends
- Update dependencies
- Review security group rules

**Quarterly:**
- Full security audit
- Penetration testing
- Compliance review
- Architecture review

## 🎯 Quick Reference: Security vs. Cost Trade-offs

| Action | Security Impact | Cost Impact | Recommendation |
|--------|----------------|-------------|----------------|
| Single NAT Gateway | ⚠️ Medium (single point of failure) | 💰 Save $32/month | ✅ OK for dev/small prod |
| Disable NAT Gateway | ⚠️ Medium (no internet from private) | 💰 Save $32-52/month | ✅ OK for dev/test only |
| Spot Instances | ⚠️ Low (potential interruptions) | 💰 Save 60-90% | ✅ OK for stateless workloads |
| Reduce log retention | ⚠️ Medium (less audit history) | 💰 Save $1-5/month | ⚠️ Balance with compliance |
| Disable VPC Flow Logs | ❌ High (blind to network traffic) | 💰 Save $1-5/month | ❌ Not recommended |
| Public API endpoint | ⚠️ Medium (larger attack surface) | 💰 No impact | ✅ Restrict CIDR blocks |
| Disable KMS encryption | ❌ Critical (unencrypted secrets) | 💰 Save $1/month | ❌ Never disable |
| Minimal logging | ❌ High (limited audit trail) | 💰 Save $1-5/month | ❌ Keep api + audit minimum |

## 📝 Implementation Checklist

### Immediate Actions (Day 1)
- [ ] Update `cluster_endpoint_public_access_cidrs` to your IP
- [ ] Review and adjust instance types based on workload
- [ ] Set appropriate log retention for your compliance needs
- [ ] Configure AWS Budgets and alerts
- [ ] Enable AWS Cost Explorer

### Week 1
- [ ] Implement Pod Security Standards
- [ ] Configure RBAC for teams
- [ ] Set up CloudWatch dashboards
- [ ] Create security alarms
- [ ] Review and customize Network ACLs

### Month 1
- [ ] Analyze cost trends and optimize
- [ ] Implement Network Policies
- [ ] Set up automated backups (Velero)
- [ ] Configure resource quotas
- [ ] Enable GuardDuty and Security Hub

### Ongoing
- [ ] Monthly cost reviews
- [ ] Quarterly security audits
- [ ] Regular dependency updates
- [ ] Continuous optimization based on usage
- [ ] Team training on security best practices

---

💡 **Remember**: Security should never be compromised for cost savings. The optimizations in this guide maintain strong security posture while reducing unnecessary expenses.
