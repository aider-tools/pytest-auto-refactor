#!/bin/bash
#set -euo pipefail

source /opt/qauser-venv/bin/activate

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
export CONFIRM_BEFORE_AIDER=${CONFIRM_BEFORE_AIDER:-false}
export REQUREMENTS_FILE=${REQUREMENTS_FILE:-"requirements.txt"}

# Function to confirm before running aider
function confirm_before_aider() {
    if [ "$CONFIRM_BEFORE_AIDER" = true ]; then
        read -p "Do you want to continue with aider? (y/n) " -n 1 -r
        echo    # (optional) move to a new line
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "Aborting aider execution."
            exit 1
        fi
    else 
        echo "Sleeping for ${SLEEP_TIME} seconds before running aider..."
        sleep ${SLEEP_TIME}
        rm -rf /workspace/${REPO_NAME}/.aider.input.history /workspace/${REPO_NAME}/.aider.chat.history.md /workspace/${REPO_NAME}/.aider.tags.cache.v3
    fi
}


# Clone the repository if it doesn't exist
if [ ! -d "/workspace/${REPO_NAME}" ]; then
    git clone https://github.com/your-username/${REPO_NAME}.git /workspace/${REPO_NAME}
fi

# Navigate to the repository
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

# Create the test code file if it doesn't exist

if [ ! -f "/workspace/${REPO_NAME}/${TEST_CODE}" ]; then
    echo "Creating ${TEST_CODE}..."
    touch /workspace/${REPO_NAME}/${TEST_CODE}
    git commit -m "Created ${TEST_CODE} file" --allow-empty


    for SOURCE_CODE in "${SOURCE_CODES[@]}"; do
        # Echo the aider command to be run
        echo "Running aider with the following command:"
        echo "aider \"$SOURCE_CODE\" \"$TEST_CODE\" \\"
        echo "      --architect --model \"$MODEL\" --editor-model \"$EDITOR_MODEL\" \\"
        echo "      --auto-commits --auto-test --yes --suggest-shell-commands \\"
        echo "      --message \"Create initial test for ${SOURCE_CODE} named ${TEST_CODE}\" \\"
        echo "      --edit-format diff"

        confirm_before_aider

        # Execute the aider command
        aider "$SOURCE_CODE" "$TEST_CODE" \
            --architect --model "$MODEL" --editor-model "$EDITOR_MODEL" \
            --auto-commits --auto-test --yes --suggest-shell-commands \
            --message "Create initial test for ${SOURCE_CODE} named ${TEST_CODE}" \
            --max-chat-history-tokens 1000 --cache-prompts --map-refresh 5 --test-cmd 'pytest' --show-diffs  \
            --edit-format diff --editor-edit-format diff
    done

    # Stage and commit changes
    git add "${TEST_CODE}"
    git commit -m "Created initial test for ${SOURCE_CODES[*]}"

    # Push changes
    git push
    git config --global credential.helper store
fi

# Run pytest on the test code
ARCHITECT_MESSAGE=$(pytest "/workspace/${REPO_NAME}/${TEST_CODE}")
echo "Processed TEST CODE: ${TEST_CODE}"
echo "pytest output: $ARCHITECT_MESSAGE"

# Process each line of pytest output
PROMPT="You are an AI language model assisting a developer with the action \"Debug\" related to \"/workspace/${TEST_CODE}\" and \"/workspace/${SOURCE_CODES[*]}\". \
The following pytest error occurred in the context of \"$ARCHITECT_MESSAGE\". \
Explain the nature of the errors, the steps you took to resolve them, \
and any potential improvements or alternative solutions that may be applicable."
echo "$PROMPT"
sleep 5s

for SOURCE_CODE in "${SOURCE_CODES[@]}"; do
    # Echo the aider command with resolved variables
    echo "Running aider with the following command:"
    echo "aider \"$SOURCE_CODE\" \"$TEST_CODE\" \\"
    echo "      --architect --model \"$MODEL\" --editor-model \"$EDITOR_MODEL\" \\"
    echo "      --auto-commits --auto-test --yes --suggest-shell-commands \\"
    echo "      --message \"$PROMPT\" \\"
    echo "      --edit-format diff"

    confirm_before_aider
    
    # Execute the aider command
    aider "$SOURCE_CODE" "$TEST_CODE" \
        --architect --model "$MODEL" --editor-model "$EDITOR_MODEL" \
        --auto-commits --auto-test --yes --suggest-shell-commands \
        --message "$PROMPT" --test-cmd "pytest /workspace/${REPO_NAME}/${TEST_CODE}" \
        --lint-cmd "pylint /workspace/${REPO_NAME}/${SOURCE_CODE}" \
        --max-chat-history-tokens 1000 --cache-prompts --map-refresh files --test-cmd 'pytest' --show-diffs  \
        --edit-format diff  --editor-edit-format diff

    # Stage and commit changes
    git add "$SOURCE_CODE"
    git commit -m "Refactored ${SOURCE_CODE} based on: $line"
done

# Push changes
git push
git config --global credential.helper store

source /opt/qauser-venv/bin/activate
python -m pytest "/workspace/${REPO_NAME}/${TEST_CODE}"

python3 /workspace/${REPO_NAME}/app.py

