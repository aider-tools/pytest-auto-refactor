#!/bin/bash
set -euo pipefail

# Function to pause execution
function pause(){
    read -s -n 1 -p "Press any key to continue . . ."
    echo ""
}

# Set environment variables
export OLLAMA_API_BASE=${OLLAMA_API_BASE:-"http://ollama.ollama.svc.cluster.local:11434"}
export MODEL=${MODEL:-"ollama/granite3-dense:8b"}
export EDITOR_MODEL=${EDITOR_MODEL:-"ollama/granite3-dense:8b"}
export SLEEP_TIME=${SLEEP_TIME:-30}
export REPO_NAME=${REPO_NAME:-"your-repo-name"}

# Clone the repository if it doesn't exist
if [ ! -d "/workspace/${REPO_NAME}" ]; then
    git clone https://github.com/your-username/${REPO_NAME}.git /workspace/${REPO_NAME}
fi

# Navigate to the repository
cd /workspace/${REPO_NAME}
git config --global --add safe.directory /workspace/${REPO_NAME}

# Define the source and test code files
export SOURCE_CODE="app.py"
export TEST_CODE="test_app.py"

# Create the test code file if it doesn't exist
if [ ! -f "/workspace/${REPO_NAME}/${TEST_CODE}" ]; then
    echo "Creating ${TEST_CODE}..."
    aider ${SOURCE_CODE} \
        --architect --model "$MODEL" --editor-model $EDITOR_MODEL \
        --auto-commits --auto-test --yes --suggest-shell-commands \
        --message "Create initial test for ${SOURCE_CODE}" \
        --edit-format diff

    # Stage and commit changes
    git add "${TEST_CODE}"
    git commit -m "Created initial test for ${SOURCE_CODE}"

    # Push changes
    git push
    git config --global credential.helper store
fi

# Run pytest on the test code
ARCHITECT_MESSAGE=$(pytest /workspace/${TEST_CODE} 2>&1 || true)
echo "Processed TEST CODE: ${TEST_CODE}"

# Process each line of pytest output
while IFS= read -r line; do
    echo "Processing: $line"
    PROMPT="You are an AI language model assisting a developer with the action \"Debug\" related to \"/workspace/${TEST_CODE}\". \
    The following pytest error occurred in the context of \"$line\". \
    Explain the nature of the errors, the steps you took to resolve them, \
    and any potential improvements or alternative solutions that may be applicable."

    aider ${SOURCE_CODE}  \
        --architect --model "$MODEL" --editor-model $EDITOR_MODEL \
        --auto-commits --auto-test --yes --suggest-shell-commands \
        --message "${line}" \
        --edit-format diff

    # Stage and commit changes
    git add "${SOURCE_CODE}"
    git commit -m "Refactored ${SOURCE_CODE} based on: ${line}"

    # Push changes
    git push
    git config --global credential.helper store

    # Optional: Wait before proceeding to the next iteration
    sleep ${SLEEP_TIME}

    # Clean up aider history files
    rm -f .aider.input.history .aider.chat.history.md .aider.tags.cache.v3
done <<< "$ARCHITECT_MESSAGE"
