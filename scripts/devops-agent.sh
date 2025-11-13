#!/bin/bash

set -e

if [[ -z "$GITHUB_TOKEN" ]]; then
  echo "The GITHUB_TOKEN is not set."
  exit 1
fi

if [[ -z "$ISSUE_NUMBER" ]]; then
  echo "The ISSUE_NUMBER is not set."
  exit 1
fi

if [[ -z "$COMMENT_BODY" ]]; then
  echo "The COMMENT_BODY is not set."
  exit 1
fi

if [[ "$COMMENT_BODY" != "/approve" ]]; then
  echo "The comment is not an approval."
  exit 0
fi

echo "The comment is an approval."
