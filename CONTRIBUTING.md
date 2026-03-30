# Contributing to CloudKube EKS Terraform Pipeline

First off, thank you for considering contributing to CloudKube EKS Terraform Pipeline! 🎉

It's people like you that make this project such a great tool for the community.

## 📋 Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Pull Request Process](#pull-request-process)
- [Coding Standards](#coding-standards)
- [Commit Message Guidelines](#commit-message-guidelines)
- [Testing](#testing)
- [Documentation](#documentation)

## 📜 Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to [eneiasbrumjr@gmail.com](mailto:eneiasbrumjr@gmail.com).

## 🤝 How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues as you might find out that you don't need to create one. When you are creating a bug report, please include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples**
- **Describe the behavior you observed and what you expected**
- **Include Terraform version, AWS provider version, and OS details**
- **Include relevant logs and error messages**

**Bug Report Template:**
```markdown
**Describe the bug**
A clear description of what the bug is.

**To Reproduce**
Steps to reproduce the behavior:
1. Run `terraform ...`
2. See error

**Expected behavior**
What you expected to happen.

**Environment:**
- Terraform Version: [e.g., 1.5.0]
- AWS Provider Version: [e.g., 5.0]
- OS: [e.g., macOS 13.0]

**Additional context**
Add any other context about the problem here.
```

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, please include:

- **Use a clear and descriptive title**
- **Provide a detailed description of the suggested enhancement**
- **Explain why this enhancement would be useful**
- **List some examples of how it would be used**

**Enhancement Request Template:**
```markdown
**Is your feature request related to a problem?**
A clear description of the problem.

**Describe the solution you'd like**
A clear description of what you want to happen.

**Describe alternatives you've considered**
Other solutions or features you've considered.

**Additional context**
Any other context or screenshots.
```

### Your First Code Contribution

Unsure where to begin? You can start by looking through these `good-first-issue` and `help-wanted` issues:

- **Good first issues** - issues which should only require a few lines of code
- **Help wanted issues** - issues which should be more involved than beginner issues

### Pull Requests

We actively welcome your pull requests! Here's how to get started:

1. Fork the repo and create your branch from `main`
2. Make your changes
3. Ensure tests pass
4. Update documentation
5. Submit a pull request

## 🚀 Getting Started

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.5
- [AWS CLI](https://aws.amazon.com/cli/) >= 2.0
- [pre-commit](https://pre-commit.com/) (optional but recommended)
- Git

### Setup Development Environment

1. **Fork and clone the repository**
   ```bash
   git clone https://github.com/YOUR-USERNAME/cloudkube-eks-terraform-pipeline-enb.git
   cd cloudkube-eks-terraform-pipeline-enb
   ```

2. **Install pre-commit hooks** (recommended)
   ```bash
   pip install pre-commit
   pre-commit install
   ```

3. **Configure AWS credentials**
   ```bash
   aws configure
   ```

4. **Initialize Terraform**
   ```bash
   cd infra
   terraform init
   ```

## 🔄 Development Workflow

1. **Create a new branch**
   ```bash
   git checkout -b feature/your-feature-name
   # or
   git checkout -b fix/your-bug-fix
   ```

2. **Make your changes**
   - Write clean, readable code
   - Follow the coding standards (see below)
   - Add tests if applicable

3. **Test your changes**
   ```bash
   cd infra
   terraform fmt -recursive
   terraform validate
   terraform plan
   ```

4. **Commit your changes**
   ```bash
   git add .
   git commit -m "feat: add amazing feature"
   ```

5. **Push to your fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a Pull Request**
   - Go to the original repository
   - Click "New Pull Request"
   - Select your fork and branch
   - Fill out the PR template
   - Submit!

## 📥 Pull Request Process

1. **Update documentation** - Ensure README and other docs are updated if needed
2. **Follow the PR template** - Fill out all sections
3. **Update CHANGELOG** - Add your changes to the unreleased section
4. **Pass all checks** - Ensure CI/CD passes
5. **Get reviews** - Wait for maintainer review
6. **Address feedback** - Make requested changes
7. **Merge** - Maintainers will merge once approved

### Pull Request Checklist

Before submitting your PR, ensure:

- [ ] Code follows the project's coding standards
- [ ] All tests pass locally
- [ ] Terraform fmt has been run
- [ ] Documentation has been updated
- [ ] Commit messages follow conventions
- [ ] PR description clearly describes the changes
- [ ] No sensitive information (keys, credentials) is included
- [ ] Variables are properly validated
- [ ] Security best practices are followed

## 📏 Coding Standards

### Terraform Style Guide

- **Use lowercase** for resource names and variables
- **Use underscores** for multi-word names (snake_case)
- **Group related resources** together
- **Add comments** for complex logic
- **Use consistent formatting** (run `terraform fmt`)
- **Validate inputs** with validation blocks
- **Use meaningful names** for variables and resources
- **Follow DRY principles** (Don't Repeat Yourself)

### Example

```hcl
# Good ✅
variable "eks_cluster_version" {
  description = "The Kubernetes version for the EKS cluster."
  type        = string
  default     = "1.28"

  validation {
    condition     = can(regex("^1\\.(2[7-9]|[3-9][0-9])$", var.eks_cluster_version))
    error_message = "EKS cluster version must be 1.27 or higher."
  }
}

# Bad ❌
variable "eksVersion" {
  type    = string
  default = "1.28"
}
```

### Directory Structure

```
├── infra/
│   ├── modules/
│   │   ├── vpc/
│   │   │   ├── main.tf
│   │   │   ├── variables.tf
│   │   │   └── outputs.tf
│   │   └── eks/
│   │       ├── main.tf
│   │       ├── variables.tf
│   │       └── outputs.tf
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── providers.tf
│   └── backend.tf
└── .github/
    └── workflows/
```

## 💬 Commit Message Guidelines

We follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
<type>(<scope>): <subject>

<body>

<footer>
```

### Types

- **feat**: A new feature
- **fix**: A bug fix
- **docs**: Documentation only changes
- **style**: Changes that don't affect code meaning (formatting, etc.)
- **refactor**: Code change that neither fixes a bug nor adds a feature
- **perf**: Performance improvement
- **test**: Adding missing tests
- **chore**: Changes to build process or auxiliary tools

### Examples

```bash
feat(eks): add spot instance support for cost optimization

Add configurable spot instance support to EKS node groups
to reduce EC2 costs by 60-90%.

Closes #123
```

```bash
fix(vpc): correct NAT Gateway conditional logic

Fixed issue where single_nat_gateway flag wasn't properly
controlling NAT Gateway creation.

Fixes #456
```

```bash
docs(readme): add cost estimation section

Added detailed cost breakdown for different configurations
to help users understand AWS costs before deployment.
```

## 🧪 Testing

### Local Testing

Before submitting a PR, test your changes:

```bash
# Format check
terraform fmt -check -recursive

# Validation
terraform validate

# Plan (without applying)
terraform plan

# Run pre-commit hooks
pre-commit run --all-files
```

### CI/CD

Our GitHub Actions workflow automatically:
- Validates Terraform syntax
- Runs security scanning (tfsec)
- Checks formatting
- Runs terraform plan for PRs

Ensure all checks pass before requesting review.

## 📚 Documentation

Good documentation is crucial! When contributing:

1. **Update README.md** if adding new features
2. **Add inline comments** for complex logic
3. **Update variable descriptions** to be clear and helpful
4. **Include examples** where appropriate
5. **Document breaking changes** clearly
6. **Update IMPROVEMENTS.md** to track changes

### Documentation Style

- Use clear, concise language
- Include code examples
- Add diagrams for complex architectures
- Provide context for decisions
- Link to relevant AWS documentation

## 🎯 Areas for Contribution

We especially welcome contributions in these areas:

- **Cost Optimization**: New strategies to reduce AWS costs
- **Security Enhancements**: Additional security controls
- **Monitoring**: CloudWatch dashboards and alarms
- **Add-ons**: New Kubernetes add-ons integration
- **Documentation**: Improved guides and examples
- **Testing**: More comprehensive tests
- **CI/CD**: Pipeline improvements
- **Multi-Region**: Support for multi-region deployments

## 🏆 Recognition

Contributors will be recognized in:
- GitHub contributors list
- CHANGELOG.md for each release
- Special mentions in release notes for significant contributions

## 📞 Getting Help

- **GitHub Issues**: For bugs and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Email**: [your-email@example.com](mailto:your-email@example.com)

## 📝 License

By contributing, you agree that your contributions will be licensed under the MIT License.

---

Thank you for contributing to CloudKube EKS Terraform Pipeline! 🚀

Your efforts help make infrastructure as code more accessible to everyone.
