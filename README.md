# Enterprise Odoo Deployment on AWS with Terraform

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-%3E%3D1.0-blue)](https://www.terraform.io/)
[![AWS](https://img.shields.io/badge/AWS-Cloud-orange)](https://aws.amazon.com/)
[![HIPAA](https://img.shields.io/badge/HIPAA-Compliant-green)](https://www.hhs.gov/hipaa/)
[![SOC2](https://img.shields.io/badge/SOC2-Ready-green)](https://www.aicpa.org/interestareas/frc/assuranceadvisoryservices/aicpasoc2report.html)

## Overview
This Terraform configuration deploys a production-ready, enterprise-grade Odoo ERP system on AWS with HIPAA and SOC-2 compliance features. The infrastructure is designed for high availability, security, and cost optimization with enterprise-level monitoring, backup, and disaster recovery capabilities.

## Architecture Features

### Security & Compliance
- **HIPAA Compliant**: All data encrypted at rest and in transit
- **SOC-2 Type II Ready**: Comprehensive logging, monitoring, and access controls
- **Zero Trust Network**: Private subnets, security groups, and NACLs
- **Encryption**: AES-256 encryption for all storage services
- **SSL/TLS**: End-to-end encryption via AWS Certificate Manager
- **IAM**: Least privilege access with role-based permissions

### High Availability & Disaster Recovery
- **Multi-AZ RDS**: Automatic failover for database
- **Auto Scaling**: EC2 instances scale based on demand
- **Load Balancer**: Application Load Balancer with health checks
- **Backup Strategy**: Automated backups with point-in-time recovery
- **Cross-Region Replication**: S3 backup replication

### Cost Optimization
- **Reserved Instances**: Cost savings for predictable workloads
- **Spot Instances**: For non-critical batch processing
- **S3 Intelligent Tiering**: Automatic cost optimization for storage
- **CloudWatch**: Resource optimization insights
- **Scheduled Scaling**: Scale down during off-hours

## Infrastructure Components

### Core Services
- **VPC**: Isolated network with public/private subnets
- **EC2**: Ubuntu instances for Odoo application
- **RDS**: PostgreSQL with Multi-AZ deployment
- **S3**: Encrypted buckets for media and backups
- **ALB**: Application Load Balancer with SSL termination

### Security Services
- **IAM**: Roles and policies for service access
- **Security Groups**: Application-level firewall rules
- **NACLs**: Network-level access control
- **AWS WAF**: Web application firewall
- **GuardDuty**: Threat detection service

### Monitoring & Backup
- **CloudWatch**: Comprehensive monitoring and alerting
- **AWS Backup**: Automated backup management
- **CloudTrail**: API call logging and auditing
- **Config**: Configuration compliance monitoring

### DNS & SSL
- **Route 53**: DNS management and health checks
- **Certificate Manager**: SSL/TLS certificate management
- **CloudFront**: CDN for static content delivery

## Directory Structure

```
├── main.tf                     # Main configuration
├── variables.tf                # Input variables
├── outputs.tf                  # Output values
├── terraform.tfvars.example    # Example variables
├── modules/
│   ├── vpc/                    # VPC and networking
│   ├── security/               # Security groups and NACLs
│   ├── iam/                    # IAM roles and policies
│   ├── ec2/                    # EC2 instances and ALB
│   ├── rds/                    # RDS PostgreSQL
│   ├── s3/                     # S3 buckets
│   ├── monitoring/             # CloudWatch and alerting
│   ├── backup/                 # AWS Backup configuration
│   ├── dns/                    # Route 53 configuration
│   └── ssl/                    # Certificate Manager
└── docs/                       # Documentation
    ├── deployment-guide.md
    ├── security-compliance.md
    └── cost-optimization.md
```

## 🚀 Quick Start

### Using Make (Recommended)
```bash
# Install required tools
make install-tools

# Quick start for development
make quick-start

# Edit configuration
vim dev.tfvars

# Deploy to development
make apply ENV=dev
```

### Manual Deployment
1. **Prerequisites**
   ```bash
   # Install Terraform
   curl -fsSL https://apt.releases.hashicorp.com/gpg | sudo apt-key add -
   sudo apt-add-repository "deb [arch=amd64] https://apt.releases.hashicorp.com $(lsb_release -cs) main"
   sudo apt-get update && sudo apt-get install terraform
   
   # Configure AWS CLI
   aws configure
   ```

2. **Deploy Infrastructure**
   ```bash
   # Clone and navigate to directory
   cd terraform-odoo-aws
   
   # Copy and customize variables
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   
   # Initialize Terraform
   terraform init
   
   # Plan deployment
   terraform plan
   
   # Deploy infrastructure
   terraform apply
   ```

3. **Post-Deployment**
   - Configure Odoo application
   - Set up SSL certificates
   - Configure monitoring alerts
   - Test backup and recovery procedures

### Available Make Commands
```bash
make help                 # Show all available commands
make init                 # Initialize Terraform
make plan ENV=dev         # Create execution plan
make apply ENV=dev        # Apply configuration
make destroy ENV=dev      # Destroy infrastructure
make security             # Run security scan
make cost                 # Estimate costs
make health-check         # Check infrastructure health
```

## Security Considerations

### Data Protection
- All EBS volumes encrypted with customer-managed KMS keys
- RDS encryption at rest with automated key rotation
- S3 bucket encryption with SSE-S3 and SSE-KMS
- In-transit encryption for all communications

### Access Control
- IAM roles with least privilege principles
- MFA enforcement for administrative access
- VPC Flow Logs for network monitoring
- CloudTrail for API auditing

### Compliance Features
- **HIPAA**: PHI data protection and audit trails
- **SOC-2**: Security controls and monitoring
- **PCI DSS**: Payment data protection (if applicable)
- **GDPR**: Data privacy and retention policies

## Cost Optimization

### Compute Optimization
- **Right-sizing**: Automated instance recommendations
- **Reserved Instances**: 1-3 year commitments for predictable workloads
- **Spot Instances**: Up to 90% savings for fault-tolerant workloads
- **Auto Scaling**: Scale based on actual demand

### Storage Optimization
- **S3 Intelligent Tiering**: Automatic cost optimization
- **EBS GP3**: Better price-performance than GP2
- **Lifecycle Policies**: Automatic data archival
- **Cross-Region Replication**: Only for critical data

### Monitoring & Alerts
- **Cost Budgets**: Automated spending alerts
- **Resource Tagging**: Cost allocation and tracking
- **Unused Resources**: Automated identification and cleanup
- **Performance Insights**: Database optimization recommendations

## Support & Maintenance

### Monitoring
- 24/7 CloudWatch monitoring
- Automated alerting for critical issues
- Performance dashboards
- Security incident response

### Backup & Recovery
- Daily automated backups
- Point-in-time recovery
- Cross-region backup replication
- Disaster recovery testing

### Updates & Patches
- Automated security patching
- Odoo version management
- Database maintenance windows
- Zero-downtime deployments

## License
This project is licensed under the MIT License - see the LICENSE file for details.

## Contributing
Please read CONTRIBUTING.md for details on our code of conduct and the process for submitting pull requests.