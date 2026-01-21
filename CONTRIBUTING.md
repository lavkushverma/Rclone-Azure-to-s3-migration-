# Contributing to Azure to S3 Migration

Thank you for your interest in contributing! This document provides guidelines for contributing to this project.

## How to Contribute

### Reporting Issues

If you encounter a bug or have a suggestion:

1. Check if the issue already exists
2. Create a new issue with:
   - Clear title and description
   - Steps to reproduce (for bugs)
   - Expected vs actual behavior
   - Environment details (OS, rclone version, etc.)
   - Relevant logs (remove sensitive information)

### Suggesting Enhancements

Enhancement suggestions are welcome:

1. Open an issue with "Enhancement:" prefix
2. Describe the enhancement in detail
3. Explain why it would be useful
4. Provide examples if possible

### Pull Requests

1. Fork the repository
2. Create a feature branch:
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. Make your changes
4. Test your changes thoroughly
5. Commit with clear messages:
   ```bash
   git commit -m "Add: description of changes"
   ```
6. Push to your fork:
   ```bash
   git push origin feature/amazing-feature
   ```
7. Open a Pull Request

## Development Guidelines

### Code Style

**Bash Scripts:**
- Use `#!/bin/bash` shebang
- Use `set -e` for error handling
- Add comments for complex logic
- Use meaningful variable names
- Follow existing formatting

**Documentation:**
- Use clear, concise language
- Include examples
- Keep formatting consistent
- Update relevant docs when changing features

### Testing

Before submitting:
- Test scripts on clean EC2 instance
- Verify all commands work
- Check for typos
- Ensure documentation is accurate

### Commit Messages

Use descriptive commit messages:
- `Add: new feature description`
- `Fix: bug description`
- `Update: documentation changes`
- `Refactor: code improvements`

## Areas for Contribution

### High Priority
- Additional cloud provider support (GCP, etc.)
- Enhanced monitoring scripts
- Performance benchmarking tools
- Automated testing framework

### Documentation
- Translations
- Video tutorials
- Additional examples
- FAQ section

### Scripts
- Pre-migration health checks
- Post-migration reporting
- Cost estimation tools
- Migration rollback scripts

## Questions?

Feel free to open an issue for:
- Questions about contributing
- Clarification on guidelines
- Discussion of ideas

## Code of Conduct

- Be respectful and inclusive
- Provide constructive feedback
- Focus on the code, not the person
- Help others learn and grow

Thank you for contributing!
