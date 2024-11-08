#!/bin/bash
#set -euo pipefail

source /opt/qauser-venv/bin/activate
# Function to pause execution
function pause(){
    read -s -n 1 -p "Press any key to continue . . ."
    echo ""
}

# Set environment variables with defaults if not already set
export OLLAMA_API_BASE=${OLLAMA_API_BASE:-"http://ollama.ollama.svc.cluster.local:11434"}
export MODEL=${MODEL:-"ollama/granite3-dense:8b"}
export EDITOR_MODEL=${EDITOR_MODEL:-"ollama/granite3-dense:8b"}
export SLEEP_TIME=${SLEEP_TIME:-30}
export REPO_NAME=${REPO_NAME:-"your-repo-name"}
export CONFIRM_BEFORE_AIDER=${CONFIRM_BEFORE_AIDER:-false}
export REQUIREMENTS_FILE=${REQUIREMENTS_FILE:-"requirements.txt"}

# Confirm before running aider function
function confirm_before_aider() {
    if [ "$CONFIRM_BEFORE_AIDER" = true ]; then
        read -p "Do you want to continue with aider? (y/n) " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborting aider execution."
            exit 1
        fi
    else 
        echo "Sleeping for ${SLEEP_TIME} seconds before running aider..."
        sleep ${SLEEP_TIME}
    fi
}

# Clone repository if not already cloned
if [ ! -d "/workspace/${REPO_NAME}" ]; then
    git clone https://github.com/your-username/${REPO_NAME}.git /workspace/${REPO_NAME}
fi

cd /workspace/${REPO_NAME}
git config --global --add safe.directory /workspace/${REPO_NAME}

# Convert SOURCE_CODES into an array
IFS=',' read -r -a SOURCE_CODES <<< "$SOURCE_CODES"

# Ensure each source file exists
for SOURCE_CODE in "${SOURCE_CODES[@]}"; do
    if [ ! -f "/workspace/${REPO_NAME}/${SOURCE_CODE}" ]; then
        echo "The source code file ${SOURCE_CODE} does not exist in the repository. Exiting..."
        exit 1
    fi
done

# Install the required dependencies
if [ ! -f "/workspace/${REPO_NAME}/${REQUREMENTS_FILE}" ]; then
    echo "The requirements file ${REQUREMENTS_FILE} does not exist in the repository. Exiting..."
    exit 1
fi
/opt/qauser-venv/bin/pip install  -r "/workspace/${REPO_NAME}/${REQUREMENTS_FILE}"

# Process each source code file using pylint
for SOURCE_CODE in "${SOURCE_CODES[@]}"; do
    echo "Running pylint on ${SOURCE_CODE}"
    
    # Run pylint and capture output
    ARCHITECT_MESSAGE=$(pylint "/workspace/${REPO_NAME}/${SOURCE_CODE}")
    echo "Processed SOURCE CODE: ${SOURCE_CODE}"
    echo "pylint output: $ARCHITECT_MESSAGE"

    # Check if pylint output indicates a perfect score and skip if so
    if echo "$ARCHITECT_MESSAGE" | grep -q "Your code has been rated at 10.00/10"; then
        echo "No issues detected in ${SOURCE_CODE}. Skipping aider."
        continue
    fi

    # Build a single prompt for all pylint messages in this file
    PROMPT="You are an AI language model assisting a developer with debugging and refactoring \"${SOURCE_CODE}\". \
The following pylint messages occurred in the context of \"${SOURCE_CODE}\":\n${ARCHITECT_MESSAGE}\n \
Explain the nature of these issues, steps to resolve them, and any potential improvements or alternative solutions."

    # Run aider on the source code file with combined pylint feedback
    echo "Running aider for pylint messages on ${SOURCE_CODE}"
    confirm_before_aider
    aider "${SOURCE_CODE}" \
        --architect --model "$MODEL" --editor-model "$EDITOR_MODEL" \
        --auto-commits --auto-test --yes --suggest-shell-commands \
        --max-chat-history-tokens 1000 --cache-prompts --map-refresh files --test-cmd 'pytest' --show-diffs  \
        --message "$PROMPT" --edit-format diff --editor-edit-format diff

    # Stage and commit changes
    git add "${SOURCE_CODE}"
    git commit -m "Refactored ${SOURCE_CODE} based on pylint feedback"
done

# Push all changes
git push
git config --global credential.helper store
