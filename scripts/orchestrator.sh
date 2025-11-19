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
  # Note: Assuming gemini run takes prompt as argument. 
  # Adjust based on actual CLI syntax if needed (e.g. piped input).
  gemini run "$prompt" --model "$model"
}

# 2. Router
if [ "$EVENT_NAME" == "issues" ]; then
  ACTION=$(jq -r .action "$GITHUB_EVENT_PATH")
  ISSUE_NUMBER=$(jq -r .issue.number "$GITHUB_EVENT_PATH")
  
  if [ "$ACTION" == "opened" ]; then
    echo "Processing Issue #$ISSUE_NUMBER..."
    ISSUE_BODY=$(jq -r .issue.body "$GITHUB_EVENT_PATH")
    
    # Determine Model for Planning
    PLAN_MODEL="gemini-2.5-flash"
    if echo "$ISSUE_BODY" | grep -iq "/model pro"; then
      PLAN_MODEL="gemini-2.5-pro"
      echo "Model override detected: Using gemini-2.5-pro"
    elif echo "$ISSUE_BODY" | grep -iq "/model flash"; then
      PLAN_MODEL="gemini-2.5-flash"
      echo "Model override detected: Using gemini-2.5-flash"
    fi
    
    PROMPT="你是一個資深工程師。請閱讀 Issue 需求，分析專案結構，並列出詳細的實作計畫 (Step-by-step)。最後請詢問使用者是否同意。需求：$ISSUE_BODY"
    
    PLAN=$(call_gemini "$PROMPT" "$PLAN_MODEL")
    echo "--- Generated Plan ---"
    echo "$PLAN"
    
    # Post Plan to Issue
    gh issue comment "$ISSUE_NUMBER" --body "$PLAN"
    # Add Label
    gh issue edit "$ISSUE_NUMBER" --add-label "agent:planning"
  fi

elif [ "$EVENT_NAME" == "issue_comment" ]; then
  ACTION=$(jq -r .action "$GITHUB_EVENT_PATH")
  
  if [ "$ACTION" == "created" ]; then
    COMMENT_BODY=$(jq -r .comment.body "$GITHUB_EVENT_PATH")
    ISSUE_NUMBER=$(jq -r .issue.number "$GITHUB_EVENT_PATH")
    echo "Processing Comment on Issue #$ISSUE_NUMBER..."
    
    # Check for approval (case insensitive)
    if echo "$COMMENT_BODY" | grep -iqE "/lgtm|approve"; then
      echo "User Approved. Triggering ACT phase."
      
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
      echo "User Feedback detected. Triggering RE-PLAN phase."
      PROMPT="使用者反饋：$COMMENT_BODY。請重新規劃。"
      PLAN=$(call_gemini "$PROMPT" "gemini-2.5-flash")
      echo "--- Updated Plan ---"
      echo "$PLAN"
      
      # Post Updated Plan
      gh issue comment "$ISSUE_NUMBER" --body "$PLAN"
    fi
  fi
fi

echo "Orchestrator finished successfully."
