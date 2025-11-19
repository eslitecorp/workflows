#!/bin/bash
set -e

echo "Starting GitHub Autonomous Gemini Agent Orchestrator..."

# 1. Parse Event
if [ -z "$GITHUB_EVENT_PATH" ]; then
  echo "Error: GITHUB_EVENT_PATH not set."
  exit 1
fi

EVENT_NAME="$GITHUB_EVENT_NAME"
echo "Event Name: $EVENT_NAME"

# Helper function to call Gemini
call_gemini() {
  local prompt="$1"
  local model="$2"
  
  echo "Running Gemini CLI with model $model..."
  gemini -p "$prompt" --model "$model" --yolo
}

# 2. Router
if [ "$EVENT_NAME" == "issues" ]; then
  ACTION=$(jq -r .action "$GITHUB_EVENT_PATH")
  ISSUE_NUMBER=$(jq -r .issue.number "$GITHUB_EVENT_PATH")
  
  if [ "$ACTION" == "opened" ]; then
    echo "Processing Issue #$ISSUE_NUMBER..."
    
    USAGE_GUIDE="👋 Hi! I'm **GAGA** (GitHub Autonomous Gemini Agent).

I'm here to help you code. To get started, please comment with one of the following commands:

- \`/gaga plan\`: I will analyze your request and propose an implementation plan.
- \`/gaga plan --model pro\`: Use the stronger Gemini 2.5 Pro model for planning.
- \`/gaga approve\` or \`/lgtm\`: I will execute the approved plan.

Waiting for your command! 🚀"
    
    # Post Usage Guide
    gh issue comment "$ISSUE_NUMBER" --body "$USAGE_GUIDE"
  fi

elif [ "$EVENT_NAME" == "issue_comment" ]; then
  ACTION=$(jq -r .action "$GITHUB_EVENT_PATH")
  
  if [ "$ACTION" == "created" ]; then
    COMMENT_BODY=$(jq -r .comment.body "$GITHUB_EVENT_PATH")
    ISSUE_NUMBER=$(jq -r .issue.number "$GITHUB_EVENT_PATH")
    echo "Processing Comment on Issue #$ISSUE_NUMBER..."
    
    # 1. Check for PLAN command
    if echo "$COMMENT_BODY" | grep -iq "/gaga plan"; then
        echo "Command detected: PLAN"
        ISSUE_BODY=$(jq -r .issue.body "$GITHUB_EVENT_PATH")
        
        # Determine Model
        PLAN_MODEL="gemini-2.5-flash"
        if echo "$COMMENT_BODY" | grep -iq "model pro"; then
          PLAN_MODEL="gemini-2.5-pro"
          echo "Model override: Using gemini-2.5-pro"
        fi
        
        PROMPT="你是一個資深工程師。請閱讀 Issue 需求，分析專案結構，並列出詳細的實作計畫 (Step-by-step)。最後請詢問使用者是否同意。需求：$ISSUE_BODY"
        
        PLAN=$(call_gemini "$PROMPT" "$PLAN_MODEL")
        echo "--- Generated Plan ---"
        echo "$PLAN"
        
        gh issue comment "$ISSUE_NUMBER" --body "$PLAN"
        gh issue edit "$ISSUE_NUMBER" --add-label "agent:planning"

    # 2. Check for APPROVE command
    elif echo "$COMMENT_BODY" | grep -iqE "/gaga approve|/lgtm"; then
      echo "Command detected: APPROVE"
      
      # Git Setup
      BRANCH_NAME="feature/issue-$ISSUE_NUMBER"
      git config user.name "github-actions[bot]"
      git config user.email "github-actions[bot]@users.noreply.github.com"
      git checkout -b "$BRANCH_NAME"
      
      # Act
      PROMPT="使用者已批准計畫。請根據計畫與 Issue 上下文，直接修改代碼。請確保代碼符合 GEMINI.md 規範。"
      RESULT=$(call_gemini "$PROMPT" "gemini-2.5-pro")
      echo "--- Act Result ---"
      echo "$RESULT"
      
      # Commit & Push
      git add .
      git commit -m "feat: implement issue #$ISSUE_NUMBER"
      git push origin "$BRANCH_NAME"
      
      # Create PR
      PR_BODY="Implemented changes for Issue #$ISSUE_NUMBER.\n\n## Changes\n$RESULT"
      gh pr create --title "feat: implement issue #$ISSUE_NUMBER" --body "$PR_BODY" --base "main" --head "$BRANCH_NAME"
      
      # Update Labels
      gh issue edit "$ISSUE_NUMBER" --remove-label "agent:planning" --add-label "agent:reviewing"
      
    else
      echo "No GAGA command detected."
    fi
  fi
fi

echo "Orchestrator finished successfully."
