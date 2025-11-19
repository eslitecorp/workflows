# Architecture & Design

## Overview
The GitHub Autonomous Gemini Agent is a "Native Agent" that runs directly within GitHub Actions. It leverages the `@google/gemini-cli` to interact with Gemini models (Flash and Pro) to understand issues, plan implementations, and write code.

## Core Decisions
- **Runtime**: GitHub Actions. Chosen for native integration with the repository and zero-infrastructure management.
- **Language**: Bash. Chosen for the Orchestrator to simplify the interaction with CLI tools (`gh`, `git`, `gemini`). Python `subprocess.run` was deemed too verbose for a glue-code heavy task.
- **AI Engine**: `gemini-cli`. Provides direct file system access and "one-shot" execution capabilities suitable for CI/CD environments.

## State Machine
The agent operates on a simple state machine triggered by GitHub Events:

1.  **PLAN Phase**
    *   **Trigger**: `issues` (opened) or `issue_comment` (feedback).
    *   **Model**: `gemini-2.5-flash` (Fast, reasoning).
    *   **Action**: Reads the issue, generates a step-by-step plan, and comments it back to the user.
    *   **Label**: `agent:planning`.

2.  **ACT Phase**
    *   **Trigger**: `issue_comment` (containing "/lgtm" or "Approve").
    *   **Model**: `gemini-2.5-pro` (High capability coding).
    *   **Action**:
        *   Creates a feature branch (`feature/issue-{n}`).
        *   Executes the plan (modifies files).
        *   Commits and Pushes.
        *   Creates a Pull Request.
    *   **Label**: `agent:reviewing`.

## Directory Structure
```
.github/workflows/agent.yml  # CI Entry point
scripts/orchestrator.sh      # Core Logic (Bash)
docs/                        # Documentation
GEMINI.md                    # Agent Persona & Context
```
