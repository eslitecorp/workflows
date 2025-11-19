#!/bin/bash
set -e

echo "Initializing GAGA (GitHub Autonomous Gemini Agent)..."

# 1. Create Labels
echo "Creating labels..."
gh label create "agent:planning" --color "FBCA04" --description "GAGA is planning" --force
gh label create "agent:reviewing" --color "0E8A16" --description "GAGA has created a PR" --force

# 2. Check Secrets
echo "Checking secrets..."
if gh secret list | grep -q "GEMINI_API_KEY"; then
  echo "✅ GEMINI_API_KEY found."
else
  echo "⚠️ GEMINI_API_KEY not found!"
  echo "Please set it using: gh secret set GEMINI_API_KEY < your_key"
fi

echo "GAGA Setup Complete! 🚀"
