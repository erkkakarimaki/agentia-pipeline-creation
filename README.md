# Create Agentia Pipeline

## Overview

This test job automates the end-to-end setup of a **Copado Agentia Pipeline** using the
[Copado Robotic Testing (CRT)](https://robotic.copado.com) platform. It logs into Agentia via
Salesforce and Copado Okta, creates a GitHub repository, establishes Git and Salesforce Sandbox
connections, creates a deployment pipeline, and adds a sample Work Item.

All test data is driven from the `data.yaml` configuration file, making the suite easy to
maintain and adapt for different environments.

---

## CRT Platform Details

| Field          | Value                               |
|----------------|-------------------------------------|
| **Project**    | Erkka Test Pipeline (ID: 111289)    |
| **Robot**      | Agentia Pipeline Robot (ID: 109629) |
| **Test Job**   | Create Agentia Pipeline (ID: 192637)|
| **Robot Kind** | Cloud                               |

---

## Repository Structure

```
.
├── agentia.robot       # Main Robot Framework test suite
├── data.yaml           # Test data and configuration file
└── README.md           # This file
```

---

## Test Suite: `agentia.robot`

### Libraries Used

| Library       | Purpose                                        |
|---------------|------------------------------------------------|
| `QForce`      | Web UI interactions (clicks, text input, etc.) |
| `QVision`     | Image-based UI interactions                    |
| `Collections` | Robot Framework built-in collection handling   |

### Test Case

#### `Create a Pipeline` *(tag: Agentia Pipeline)*

This is the single test case in the suite. It performs the following steps in order:

1. **Navigate to Agentia Pipelines** via the Agentia home screen.
2. **Create a new GitHub repository** (e.g., `MyTestRepo`) using the configured email and GitHub TOTP.
3. **Add a GitHub Repository Connection** (authenticated) linking the new repository to Agentia.
4. **Add Salesforce Sandbox Connections** for each environment defined in `data.yaml` (Dev, QA, Prod), including authorization and connection testing.
5. **Create a new Pipeline** (e.g., `My Test Pipeline`) with the three sandbox environments as stages.
6. **Create Work Items** as defined in `data.yaml` via the Work Manager.

### Keywords

| Keyword | Description |
|---|---|
| `Setup Browser` | Opens Chrome, sets library search order, configures timeouts and delays. |
| `End Suite` | Closes all open browser windows. |
| `Navigate to Pipelines` | Opens the Agentia Pipeline view, handles double-login scenarios. |
| `Login` | Logs into Salesforce via Copado custom domain, handles MFA if `${secret}` is provided. |
| `Fill MFA` | Retrieves a TOTP code and fills the MFA verification dialog. |
| `Home` | Navigates to the home URL and logs in if the session has expired. |
| `Create new GitHub repository` | Opens GitHub in a new window, authenticates, and creates a private repository with a README. |
| `Navigate to Connections` | Navigates to the Agentia Connections page and opens the Add Connection modal. |
| `Add new GitHub Repository Connection Authenticated` | Creates a GitHub connection when an active GitHub session already exists. |
| `Add new GitHub Repository Connection` | Creates a GitHub connection with a fresh Google authentication flow. |
| `Add new GitHub Repository Connection Un-Authenticated` | Creates a GitHub connection when no active session exists. |
| `Add new Salesforce Sandbox Connection` | Creates a Salesforce Org connection, authorizes it, and retries if re-authorization is needed. |
| `Add Environment` | Fills in a single environment row within the New Pipeline modal. |
| `Create new Pipeline` | Creates a new Agentia Pipeline with the specified name, repository, and environments. |

---

## Configuration: `data.yaml`

All test data is centralized in this file. No hardcoded values exist in the robot script.
Replace the example values below with your own before running the suite.

```yaml
# Agentia Login
agentia_login_url:      https://app.copado.com
agentia_login_username: user@example.com
agentia_pipeline_name:  My Test Pipeline

# GitHub Repository
git_repository_provider: GitHub
git_repository_name:     MyTestRepo
git_repository_username: my-github-username
git_repository_email:    user@example.com

# Salesforce Sandboxes
sandboxes:
  - name: mydev   | short_name: Dev  | username: user@example.com.dev
  - name: myqa    | short_name: QA   | username: user@example.com.qa
  - name: myprod  | short_name: Prod | username: user@example.com.prod

# Work Items
workitems:
  - title: Sample Work Item | issue: CRM-1234 | description: This is a sample work item.
```

---

## Secret Variables

The following sensitive variables must be configured in the CRT test job's **Variables** section.
They are **never** stored in `data.yaml` or `agentia.robot`.

| Variable | Scope | Description |
|---|---|---|
| `agentia_login_password` | Job | Password for the Agentia/Salesforce login user. |
| `dev_password` | Job | Password for the Dev sandbox Salesforce user. |
| `qa_password` | Job | Password for the QA sandbox Salesforce user. |
| `prod_password` | Job | Password for the Prod sandbox Salesforce user. |
| `github_totp` | Job | TOTP secret used to generate GitHub OTP codes. |
| `secret` | Job | TOTP secret for Salesforce MFA (optional; MFA is skipped if not set). |

> **Security Note:** All variables above must be marked as **sensitive** and **encrypted** in CRT.
> Never commit credentials to version control.

---

## Prerequisites

Before running this test job, ensure the following are in place:

1. A valid **Agentia / Salesforce** account with access to the Copado Agentia platform.
2. A **GitHub** account with permissions to create repositories under your configured username.
3. Active **Salesforce Sandbox** environments for Dev, QA, and Prod as defined in `data.yaml`.
4. All **secret variables** configured in the CRT test job (see table above).
5. The CRT **cloud robot** is available and healthy.

---

## Execution

The test job can be triggered directly from the CRT platform:

1. Navigate to **Project:** Erkka Test Pipeline.
2. Open **Test Job:** Create Agentia Pipeline.
3. Click **Run** to trigger a new build.

Alternatively, the job can be scheduled or triggered via the CRT API or AI Context Hub.

---

## Last Successful Run

| Field | Value |
|---|---|
| **Run ID** | 5388576 |
| **Status** | Succeeded |
| **Duration** | 121 seconds |
| **Tests Passed** | 1 / 1 |
| **Date** | 2026-07-16 |
| **Report** | [View Report](https://robotic.copado.com/robots/111289/r/109629/suite/192637/runs/5388576/report) |

---

## Notes

* The `${secret}` variable controls MFA behavior. If it is set to a valid TOTP secret, the `Fill MFA` keyword is invoked automatically. If it is `${None}` (not set), MFA is skipped.
* The `Add new Salesforce Sandbox Connection` keyword includes a retry loop (up to 3 attempts) to handle intermittent re-authorization prompts from Salesforce.
* The suite uses a `0.3s` keyword delay (`SetConfig Delay`) to improve stability in cloud environments with limited resources.
* The default timeout for all UI interactions is set to `45s` to accommodate slower Salesforce page loads.
