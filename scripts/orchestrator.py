import os
import json
import sys
import subprocess
from gemini_client import GeminiClient

def main():
    print("Starting GitHub Autonomous Gemini Agent Orchestrator...")

    # 1. Parse Event
    event_path = os.environ.get('GITHUB_EVENT_PATH')
    if not event_path:
        print("Error: GITHUB_EVENT_PATH not set.")
        sys.exit(1)

    with open(event_path, 'r') as f:
        event_data = json.load(f)

    event_name = os.environ.get('GITHUB_EVENT_NAME')
    print(f"Event Name: {event_name}")

    # 2. Simple Router
    client = GeminiClient()
    
    if event_name == 'issues':
        action = event_data.get('action')
        issue_number = event_data.get('issue', {}).get('number')
        
        if action == 'opened':
            print(f"Processing Issue #{issue_number}...")
            issue_body = event_data.get('issue', {}).get('body', '')
            prompt = f"你是一個資深工程師。請閱讀 Issue 需求，分析專案結構，並列出詳細的實作計畫 (Step-by-step)。最後請詢問使用者是否同意。需求：{issue_body}"
            
            plan = client.run_prompt(prompt, model="gemini-2.5-flash")
            print("--- Generated Plan ---")
            print(plan)
            
            # Post Plan to Issue
            subprocess.run(["gh", "issue", "comment", str(issue_number), "--body", plan], check=False)
            # Add Label
            subprocess.run(["gh", "issue", "edit", str(issue_number), "--add-label", "agent:planning"], check=False)

    elif event_name == 'issue_comment':
        action = event_data.get('action')
        if action == 'created':
            comment_body = event_data.get('comment', {}).get('body', '')
            issue_number = event_data.get('issue', {}).get('number')
            print(f"Processing Comment on Issue #{issue_number}...")
            
            if '/lgtm' in comment_body.lower() or 'approve' in comment_body.lower():
                print("User Approved. Triggering ACT phase.")
                
                # Git Setup
                branch_name = f"feature/issue-{issue_number}"
                subprocess.run(["git", "config", "user.name", "github-actions[bot]"], check=False)
                subprocess.run(["git", "config", "user.email", "github-actions[bot]@users.noreply.github.com"], check=False)
                subprocess.run(["git", "checkout", "-b", branch_name], check=False)
                
                # Act
                prompt = "使用者已批准計畫。請根據計畫與 Issue 上下文，直接修改代碼。請確保代碼符合 GEMINI.md 規範。"
                result = client.run_prompt(prompt, model="gemini-2.5-pro")
                print("--- Act Result ---")
                print(result)
                
                # Commit & Push
                subprocess.run(["git", "add", "."], check=False)
                subprocess.run(["git", "commit", "-m", f"feat: implement issue #{issue_number}"], check=False)
                subprocess.run(["git", "push", "origin", branch_name], check=False)
                
                # Create PR
                pr_body = f"Implemented changes for Issue #{issue_number}.\n\n## Changes\n{result}"
                subprocess.run(["gh", "pr", "create", "--title", f"feat: implement issue #{issue_number}", "--body", pr_body, "--base", "main", "--head", branch_name], check=False)
                
                # Update Labels
                subprocess.run(["gh", "issue", "edit", str(issue_number), "--remove-label", "agent:planning", "--add-label", "agent:reviewing"], check=False)
                
            else:
                print("User Feedback detected. Triggering RE-PLAN phase.")
                prompt = f"使用者反饋：{comment_body}。請重新規劃。"
                plan = client.run_prompt(prompt, model="gemini-2.5-flash")
                print("--- Updated Plan ---")
                print(plan)
                
                # Post Updated Plan
                subprocess.run(["gh", "issue", "comment", str(issue_number), "--body", plan], check=False)

    print("Orchestrator finished successfully.")

    print("Orchestrator finished successfully.")

if __name__ == "__main__":
    main()
