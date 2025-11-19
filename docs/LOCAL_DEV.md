# Local Development Guide

This guide explains how to run and test the agent logic locally without triggering GitHub Actions.

## Prerequisites
1.  **Gemini CLI**: Install via npm.
    ```bash
    npm install -g @google/gemini-cli
    ```
2.  **GitHub CLI (`gh`)**: Install and authenticate.
    ```bash
    brew install gh
    gh auth login
    ```
3.  **jq**: For JSON parsing in Bash.
    ```bash
    brew install jq
    ```
4.  **Environment Variables**:
    *   `GEMINI_API_KEY`: Your Google Gemini API Key.
    *   `GITHUB_TOKEN`: A PAT with repo permissions (or use `gh auth token`).

## Running Locally

The `orchestrator.sh` script relies on GitHub Action environment variables. We can mock these.

### 1. Mock Payloads
Create JSON files to simulate GitHub events.

**`mock_issue_opened.json`**
```json
{
  "action": "opened",
  "issue": {
    "number": 1,
    "title": "Test Issue",
    "body": "Build a simple Hello World python script."
  }
}
```

**`mock_issue_approve.json`**
```json
{
  "action": "created",
  "issue": { "number": 1 },
  "comment": { "body": "LGTM" }
}
```

### 2. Execute Script
Export the necessary variables and run the script.

**Test Planning (Issue Opened)**
```bash
export GITHUB_EVENT_NAME="issues"
export GITHUB_EVENT_PATH="mock_issue_opened.json"
./scripts/orchestrator.sh
```

**Test Acting (Approve)**
```bash
export GITHUB_EVENT_NAME="issue_comment"
export GITHUB_EVENT_PATH="mock_issue_approve.json"
./scripts/orchestrator.sh
```

## Debugging
- The script prints logs to stdout.
- Check `git status` to see if files were modified by the agent.
