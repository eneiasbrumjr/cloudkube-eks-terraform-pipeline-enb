/affor# CloudKube EKS Terraform Pipeline

[![Terraform](https://img.shields.io/badge/Terraform-1.5+-623CE4?logo=terraform)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-EKS-FF9900?logo=amazon-aws)](https://aws.amazon.com/eks/)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

A production-ready, enterprise-grade Terraform infrastructure-as-code solution for provisioning AWS EKS clusters following AWS Well-Architected Framework best practices.

## 🌟 Features

### Infrastructure
- **VPC Architecture**: Multi-AZ VPC with public and private subnets
- **EKS Cluster**: Managed Kubernetes cluster with configurable version
- **Node Groups**: Auto-scaling managed node groups with mixed instance types
- **Network Security**: VPC Flow Logs, Security Groups, and Network ACLs
- **High Availability**: Multi-AZ deployment with redundant NAT Gateways

### Security
- **Encryption at Rest**: KMS encryption for EKS secrets
- **IAM Roles for Service Accounts (IRSA)**: Fine-grained pod-level permissions
- **Private Endpoints**: Configurable cluster endpoint access
- **Control Plane Logging**: Comprehensive audit and diagnostic logs
- **Security Scanning**: Automated tfsec security analysis in CI/CD

### Observability
- **VPC Flow Logs**: Network traffic monitoring via CloudWatch
- **EKS Control Plane Logs**: API, audit, authenticator, controller manager, and scheduler logs
- **CloudWatch Integration**: Centralized log management
- **Metrics**: Ready for integration with Prometheus and CloudWatch Container Insights

### Cost Optimization
- **Spot Instances**: Optional support for cost-effective workloads
- **Mixed Instance Types**: Diversified instance types for cost savings
- **NAT Gateway Options**: Single or multi-AZ NAT configuration
- **Auto-scaling**: Dynamic node scaling based on workload

### Operational Excellence
- **CI/CD Pipeline**: GitHub Actions workflow for automated deployments
- **Pre-commit Hooks**: Local validation before commits
- **Infrastructure as Code**: Version-controlled, repeatable deployments
- **Automated Documentation**: Self-updating Terraform docs
- **Modular Design**: Reusable VPC and EKS modules

## 📋 Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.5
- [AWS CLI](https://docs.aws.amazon.com/cli/latest/userguide/cli-chap-install.html) >= 2.0
- [kubectl](https://kubernetes.io/docs/tasks/tools/) >= 1.27
- AWS Account with appropriate IAM permissions
- (Optional) [pre-commit](https://pre-commit.com/) for local validation
- (Optional) [tflint](https://github.com/terraform-linters/tflint) for linting
- (Optional) [tfsec](https://github.com/aquasecurity/tfsec) for security scanning

## 🚀 Quick Start

### 1. Clone the Repository

```bash
git clone https://github.com/eneiasbrumjr/cloudkube-eks-terraform-pipeline-enb.git
cd cloudkube-eks-terraform-pipeline-enb
```

### 2. Configure Variables

```bash
cd infra
cp terraform.tfvars.example terraform.tfvars
# Edit terraform.tfvars with your configuration
```

### 3. Configure AWS Credentials

```bash
export AWS_ACCESS_KEY_ID="your-access-key"
export AWS_SECRET_ACCESS_KEY="your-secret-key"
export AWS_REGION="us-east-1"
```

### 4. Initialize and Deploy

```bash
terraform init
terraform plan
terraform apply
```

### 5. Configure kubectl

```bash
aws eks update-kubeconfig --region us-east-1 --name cloudkube-eks-dev
kubectl get nodes
```

## 📁 Project Structure

```
.
├── .github/
│   └── workflows/
│       └── terraform-eks-pipeline.yml  # CI/CD pipeline
├── infra/
│   ├── modules/
│   │   ├── vpc/                        # VPC module
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── eks/                        # EKS module
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   ├── backend.tf                      # Backend configuration
│   ├── providers.tf                    # Provider configuration
│   ├── main.tf                         # Root module
│   ├── variables.tf                    # Input variables
│   ├── outputs.tf                      # Output values
│   └── terraform.tfvars.example        # Example variables
├── .tflint.hcl                         # TFLint configuration
├── .pre-commit-config.yaml             # Pre-commit hooks
└── README.md                           # This file
```

## 🔧 Configuration Options

### VPC Configuration

| Variable | Description | Default | Type |
|----------|-------------|---------|------|
| `vpc_cidr_block` | CIDR block for VPC | `10.0.0.0/16` | string |
| `public_subnet_cidr_blocks` | Public subnet CIDRs | `["10.0.1.0/24", "10.0.2.0/24"]` | list(string) |
| `private_subnet_cidr_blocks` | Private subnet CIDRs | `["10.0.3.0/24", "10.0.4.0/24"]` | list(string) |
| `enable_nat_gateway` | Enable NAT Gateway | `true` | bool |
| `single_nat_gateway` | Use single NAT Gateway | `false` | bool |
| `enable_vpc_flow_logs` | Enable VPC Flow Logs | `true` | bool |

### EKS Configuration

| Variable | Description | Default | Type |
|----------|-------------|---------|------|
| `eks_cluster_version` | Kubernetes version | `1.28` | string |
| `eks_desired_capacity` | Desired node count | `2` | number |
| `eks_max_size` | Maximum node count | `4` | number |
| `eks_min_size` | Minimum node count | `1` | number |
| `eks_instance_types` | Instance types | `["t3.medium", "t3a.medium"]` | list(string) |
| `enable_cluster_encryption` | Enable KMS encryption | `true` | bool |
| `enable_irsa` | Enable IRSA | `true` | bool |

See [terraform.tfvars.example](infra/terraform.tfvars.example) for complete configuration options.

## 🔐 Security Best Practices

### Implemented Security Controls

1. **Encryption**
   - KMS encryption for EKS secrets
   - Encrypted CloudWatch Logs
   - HTTPS endpoints only

2. **Network Security**
   - Private subnets for worker nodes
   - Security groups with least privilege
   - VPC Flow Logs enabled
   - Network ACLs configured

3. **IAM Security**
   - IRSA for pod-level permissions
   - Least privilege IAM roles
   - No hardcoded credentials
   - SSM access for debugging (no SSH required)

4. **Compliance**
   - Audit logging enabled
   - Control plane logging
   - Automated security scanning
   - Resource tagging for governance

### Recommended Additional Security

1. **Restrict API Access**: Update `allowed_cidr_blocks` to your IP/VPN
2. **Enable Pod Security Standards**: Implement PSS in workloads
3. **Use AWS Secrets Manager**: For application secrets
4. **Implement Network Policies**: Control pod-to-pod communication
5. **Enable GuardDuty**: For threat detection

## 🔄 CI/CD Pipeline

### GitHub Actions Workflow

The pipeline includes:

1. **Validation Job**
   - Terraform format check
   - Terraform validation
   - Automated PR comments

2. **Security Scan Job**
   - tfsec security analysis
   - SARIF report upload
   - Security findings in PR

3. **Plan Job** (Pull Requests)
   - Infrastructure plan
   - Plan output in PR comments
   - Change detection

4. **Apply Job** (Main branch)
   - Automated deployment
   - Terraform docs generation
   - Production environment

### Required GitHub Secrets

```bash
AWS_ACCESS_KEY_ID       # AWS access key
AWS_SECRET_ACCESS_KEY   # AWS secret key
AWS_REGION             # AWS region (optional, defaults to us-east-1)
```

### Optional: Use OIDC Authentication

For enhanced security, configure OIDC instead of long-lived credentials:

```yaml
# Uncomment in .github/workflows/terraform-eks-pipeline.yml
role-to-assume: ${{ secrets.AWS_ROLE_ARN }}
role-session-name: GitHubActions-${{ github.run_id }}
```

## 🛠️ Local Development

### Pre-commit Hooks

Install and configure pre-commit hooks for local validation:

```bash
pip install pre-commit
pre-commit install
pre-commit run --all-files
```

### Manual Validation

```bash
# Format check
terraform fmt -check -recursive

# Validate configuration
terraform validate

# Security scan
tfsec infra/

# Lint
tflint --config=.tflint.hcl
```

## 📊 AWS Well-Architected Framework Alignment

### Operational Excellence
✅ Infrastructure as Code with Terraform
✅ Automated CI/CD pipeline
✅ Comprehensive logging and monitoring
✅ Automated documentation

### Security
✅ Encryption at rest and in transit
✅ Least privilege IAM roles
✅ Network isolation and segmentation
✅ Audit logging enabled
✅ Automated security scanning

### Reliability
✅ Multi-AZ deployment
✅ Auto-scaling capabilities
✅ Managed services (EKS, RDS-ready)
✅ Health checks and monitoring

### Performance Efficiency
✅ Right-sized instance types
✅ Auto-scaling based on demand
✅ Container orchestration
✅ Efficient resource allocation

### Cost Optimization
✅ Spot instance support
✅ Mixed instance types
✅ Auto-scaling to match demand
✅ Resource tagging for cost allocation
✅ Configurable NAT Gateway strategy

### Sustainability
✅ Auto-scaling to minimize waste
✅ Region selection capability
✅ Efficient resource utilization

## 📚 Additional Resources

- [AWS EKS Best Practices Guide](https://aws.github.io/aws-eks-best-practices/)
- [Terraform AWS Provider Documentation](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)
- [Kubernetes Documentation](https://kubernetes.io/docs/home/)
- [AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)

## 🤝 Contributing

Contributions are welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Run pre-commit checks
5. Submit a pull request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 👤 Author

**Eneias Brum Jr**
- GitHub: [@eneiasbrumjr](https://github.com/eneiasbrumjr)

## 🙏 Acknowledgments

- AWS for EKS and comprehensive documentation
- HashiCorp for Terraform
- The Kubernetes community
- All contributors to this project

## Terraform Documentation

<!-- BEGIN_TF_DOCS -->
<!-- END_TF_DOCS -->

---

⭐ If you find this project helpful, please consider giving it a star!
