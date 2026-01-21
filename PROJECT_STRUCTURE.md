# Project Structure

```
azure-to-s3-migration/
│
├── README.md                      # Main documentation with overview and usage
├── QUICK_REFERENCE.md             # Quick command reference guide
├── LICENSE                        # MIT License
├── CHANGELOG.md                   # Version history and changes
├── CONTRIBUTING.md                # Contribution guidelines
├── .gitignore                     # Git ignore rules
│
├── scripts/                       # Automation scripts
│   ├── setup.sh                   # Interactive setup script
│   ├── migrate.sh                 # Migration execution script
│   └── verify.sh                  # Post-migration verification script
│
├── config/                        # Configuration templates
│   ├── rclone.conf.template       # Rclone configuration template
│   └── azure-principal.json.template  # Azure SP credentials template
│
├── docs/                          # Detailed documentation
│   ├── SETUP.md                   # Step-by-step setup guide
│   ├── TROUBLESHOOTING.md         # Common issues and solutions
│   └── BEST_PRACTICES.md          # Migration best practices
│
└── examples/                      # Example scripts and configurations
    ├── azure-setup.sh             # Azure CLI setup commands
    ├── aws-setup.sh               # AWS CLI setup commands
    └── iam-policy.json            # Example AWS IAM policy

```

## File Descriptions

### Root Files

- **README.md**: Main entry point with project overview, quick start, and comprehensive usage instructions
- **QUICK_REFERENCE.md**: Quick command cheat sheet for common operations
- **LICENSE**: MIT License for the project
- **CHANGELOG.md**: Version history and release notes
- **CONTRIBUTING.md**: Guidelines for contributing to the project
- **.gitignore**: Prevents committing sensitive configuration files

### Scripts Directory

All scripts are executable (`chmod +x`) and include:

- **setup.sh**: Interactive script that guides users through:
  - Installing rclone
  - Configuring Azure Service Principal
  - Setting up AWS credentials
  - Creating configuration files
  - Testing connectivity

- **migrate.sh**: Production migration script with:
  - Optimized transfer settings
  - Progress monitoring
  - Logging
  - Error handling

- **verify.sh**: Post-migration verification that:
  - Compares file counts
  - Checks file sizes
  - Performs checksum validation
  - Generates detailed reports

### Config Directory

Template files for configuration (do not contain actual credentials):

- **rclone.conf.template**: Template for rclone configuration with placeholders
- **azure-principal.json.template**: Template for Azure Service Principal credentials

### Docs Directory

Comprehensive documentation:

- **SETUP.md**: Detailed, step-by-step setup instructions covering:
  - Prerequisites
  - EC2 instance setup
  - Azure configuration
  - AWS configuration
  - Troubleshooting

- **TROUBLESHOOTING.md**: Solutions for common issues:
  - Authentication problems
  - Connection issues
  - Performance tuning
  - File transfer errors

- **BEST_PRACTICES.md**: Production guidelines including:
  - Pre-migration planning
  - Security best practices
  - Performance optimization
  - Data validation
  - Cost optimization

### Examples Directory

Practical examples and templates:

- **azure-setup.sh**: Complete Azure CLI commands for Service Principal setup
- **aws-setup.sh**: Complete AWS CLI commands for IAM role and S3 bucket setup
- **iam-policy.json**: Example IAM policy with required S3 permissions

## Getting Started

1. Clone or download this repository
2. Read the README.md for overview
3. Follow docs/SETUP.md for detailed setup
4. Run scripts/setup.sh for automated configuration
5. Use QUICK_REFERENCE.md for common commands

## Security Notes

- Never commit actual credentials or configuration files to version control
- The .gitignore file protects sensitive files by default
- All templates use placeholders that must be replaced with real values
- Follow the principle of least privilege for IAM roles and Service Principals
