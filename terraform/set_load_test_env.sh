#!/bin/bash

# set_load_test_env.sh
# Script to load environment variables from load_test_variables.env file

# Get the directory of the script
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )"
ENV_FILE="${SCRIPT_DIR}/load_test_variables.env"

# Check if the env file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file $ENV_FILE not found!"
    exit 1
fi

# Read and export each variable from the file
while IFS= read -r line || [[ -n "$line" ]]; do
    # Skip empty lines and comments
    if [[ -z "$line" || "$line" == \#* ]]; then
        continue
    fi
    
    # Check if the line contains an equals sign
    if [[ ! "$line" =~ "=" ]]; then
        continue
    fi
    
    # Extract variable name (everything before the first equals sign)
    var_name="${line%%=*}"
    # Remove any trailing whitespace from var_name
    var_name="$(echo "$var_name" | xargs)"
    
    # Extract value (everything after the first equals sign)
    var_value="${line#*=}"
    
    # Remove leading/trailing quotes if present
    if [[ "$var_value" =~ ^\".*\"$ ]]; then
        var_value="${var_value#\"}"
        var_value="${var_value%\"}"
    fi
    
    # Export the variable
    export "$var_name"="$var_value"
    echo "Exported: $var_name=$var_value"
done < "$ENV_FILE"

echo "Environment variables from $ENV_FILE have been loaded."