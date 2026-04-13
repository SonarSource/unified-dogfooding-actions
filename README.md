# unified-dogfooding-actions

Reusable GitHub Actions for [Unified Platform Dogfooding](https://docs.google.com/document/d/1uYRuki3lQEfhbUbqHXXsyXZZViYVk5lSSuxXk22uz3g/)
at SonarSource.

Maintained by the **Platform Engineering Experience squad** (`@sonarsource/platform-eng-xp-squad`).

## Actions

### [`run-iris`](./run-iris/README.md)

Runs the [IRIS](https://github.com/SonarSource/iris) analysis tool to synchronize issues between SonarQube instances (Next, SQC-EU, SQC-US).
See the [run-iris README](./run-iris/README.md) for usage details and examples.

## Development

### Pre-commit

This repository uses [pre-commit](https://pre-commit.com/) to enforce code quality checks. Install it and run:

```sh
pre-commit install
```

Hooks run automatically on every commit. To run them manually:

```sh
pre-commit run --all-files
```

## Release

See [release](https://github.com/SonarSource/ci-github-actions/#release).
