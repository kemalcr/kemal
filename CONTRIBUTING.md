# Contributing to Kemal

Thank you for your interest in contributing to Kemal! We love pull requests from everyone.

## Getting Started

1. **Fork** the repository on GitHub.
2. **Clone** your fork locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/kemal.git
   cd kemal
   ```
3. **Install dependencies**:
   ```bash
   shards install
   ```

## Running Tests

Before submitting a pull request, please ensure that all tests pass.

```bash
crystal spec
```

## Code Style

Kemal follows the standard Crystal code style. Please ensure your code is formatted correctly before committing.

```bash
crystal tool format
```

## Quality Checks (Before Opening PR)

Please run formatting, lint, and tests in this order:

```bash
crystal tool format
bin/ameba
crystal spec
```

Optional one-liner:

```bash
crystal tool format && bin/ameba && crystal spec
```

## Submitting a Pull Request

1. Create a new branch for your feature or bug fix:
   ```bash
   git checkout -b my-new-feature
   ```
2. Commit your changes with descriptive commit messages.
3. Push your branch to your fork:
   ```bash
   git push origin my-new-feature
   ```
4. Open a **Pull Request** on the main Kemal repository.
5. Describe your changes and link to any relevant issues.

### Pull Request Checklist

- [ ] Code is formatted with `crystal tool format`
- [ ] Lint checks pass (`bin/ameba`)
- [ ] Specs pass (`crystal spec`)
- [ ] New behavior is covered by specs
- [ ] Changelog is updated when needed

## Reporting Bugs

If you find a bug, please open an issue on GitHub with:
- A clear title and description.
- Steps to reproduce the issue.
- The version of Kemal and Crystal you are using.

## Reporting Security Vulnerabilities

Please do **not** open a public GitHub issue for security vulnerabilities.
See our [Security Policy](SECURITY.md) for how to report them privately.

## Feature Requests

We welcome new ideas! Please open an issue to discuss your feature request before implementing it.

Thank you for contributing to Kemal! 🚀
