# Run IRIS Analysis Action

A reusable GitHub composite action that runs SonarSource IRIS analysis tool to synchronize projects between SonarQube instances.

## Usage

### Pre-requisite

Before adding the run-iris step to your GH Actions workflow, be sure to first follow the steps in
[Unified Platform Dogfooding](https://docs.google.com/document/d/1uYRuki3lQEfhbUbqHXXsyXZZViYVk5lSSuxXk22uz3g/edit?tab=t.0) to set up
your Shadow Scans. This will only work once you have your projects created in the Shadow Platforms and scans running.

### External Repository Usage

When using this action from another repository (e.g., if moved to a dedicated action repository):

```yaml
- name: Run IRIS Analysis
  uses: SonarSource/unified-dogfooding-actions/run-iris@v1
  with:
    primary_project_key: "SonarSource_your-project-name"
    primary_platform: "Next" # Platform of the primary platform (Next, SQC-EU, SQC-US)
    shadow1_project_key: "SonarSource_your-project-name"
    shadow1_platform: "SQC-EU" # Platform of the first shadow platform (Next, SQC-EU, SQC-US)
    shadow2_project_key: "SonarSource_your-project-name"
    shadow2_platform: "SQC-US" # Platform of the second shadow platform (Next, SQC-EU, SQC-US)
    organization: "sonarsource" # Optional: Organization name
```

### Basic Usage

```yaml
jobs:
  run-iris:
    runs-on: sonar-runner-on-demand
    permissions:
      id-token: write
      contents: read
    steps:
      - name: Run IRIS Analysis
        uses: SonarSource/unified-dogfooding-actions/run-iris@v1
        with:
          primary_project_key: "SonarSource_your-project-name"
          primary_platform: "Next" # Platform of the primary platform (Next, SQC-EU, SQC-US)
          shadow1_project_key: "SonarSource_your-project-name"
          shadow1_platform: "SQC-EU" # Platform of the first shadow platform (Next, SQC-EU, SQC-US)
          shadow2_project_key: "SonarSource_your-project-name"
          shadow2_platform: "SQC-US" # Platform of the second shadow platform (Next, SQC-EU, SQC-US)
          organization: "your-organization" # Optional: Organization name
```

### Complete Workflow Example

```yaml
name: Run IRIS Analysis

permissions:
  id-token: write
  contents: read
  pull-requests: read
  statuses: read
  checks: read

on:
  schedule:
    - cron: '20 */12 * * *'
  workflow_dispatch:
    inputs:
      github_environment:
        description: 'GitHub Environment'
        required: false
        type: string
        default: "ManualDispatch"
      runner_label:
        description: 'GitHub Action runner'
        required: false
        type: string
        default: "ubuntu-latest"

jobs:
  run-iris:
    runs-on: ${{ github.event_name == 'workflow_dispatch' && inputs.runner_label || 'ubuntu-latest' }}
    steps:
      - name: Run IRIS Analysis
        uses: SonarSource/unified-dogfooding-actions/run-iris@v1
        with:
          primary_project_key: "SonarSource_your-project-name"
          primary_platform: "Next" # Platform of the primary platform (Next, SQC-EU, SQC-US)
          shadow1_project_key: "SonarSource_your-project-name"
          shadow1_platform: "SQC-EU" # Platform of the first shadow platform (Next, SQC-EU, SQC-US)
          shadow2_project_key: "SonarSource_your-project-name"
          shadow2_platform: "SQC-US" # Platform of the second shadow platform (Next, SQC-EU, SQC-US)
          organization: "your-organization" # Optional: Organization name
          github_environment: ${{ github.event_name == 'workflow_dispatch' && inputs.github_environment || 'Scheduled' }}
```

## Inputs

### Required Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `primary_project_key` | Project key of the primary platform | Yes | - |
| `primary_platform` | Platform of the primary platform (Next, SQC-EU, SQC-US) | Yes | - |
| `shadow1_project_key` | Project key of the first shadow platform | Yes | - |
| `shadow1_platform` | Platform of the first shadow platform (Next, SQC-EU, SQC-US) | Yes | - |
| `shadow2_project_key` | Project key of the second shadow platform | Yes | - |
| `shadow2_platform` | Platform of the second shadow platform (Next, SQC-EU, SQC-US) | Yes | - |

### Optional Inputs

| Input | Description | Required | Default |
|-------|-------------|----------|---------|
| `github_environment` | GitHub Environment | No | `ManualDispatch` |
| `organization` | Organization name | No | `sonarsource` |
| `sonar_sqc_eu_url` | SonarCloud EU URL | No | `https://sonarcloud.io` |
| `sonar_sqc_us_url` | SonarCloud US URL | No | `https://sonarqube.us` |
| `sonar_next_url` | SonarQube Next URL | No | `https://next.sonarqube.com/sonarqube` |

## Prerequisites

### Required Permissions

The workflow using this action must have the following permissions:

```yaml
permissions:
  id-token: write    # Required for vault authentication
  contents: read     # Required for checkout
```

### Required Secrets

This action requires access to SonarSource vault with the following secrets:

- `development/kv/data/iris` - IRIS tokens for different instances
- `development/artifactory/token/{REPO_OWNER_NAME_DASH}-private-reader` - Artifactory credentials
- `development/kv/data/repox` - Artifactory URL
