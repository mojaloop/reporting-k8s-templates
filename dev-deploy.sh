#!/bin/bash
# Usage: ./apply-template.sh <template-file>
# This script is a utility to remove Helm templating before deploying for development purposes.
set -e  # Exit immediately if a command exits with a non-zero status

TEMPLATE_FILE="$1"  # Get the first argument as the template file

# Check if the template file argument is provided
if [[ -z "$TEMPLATE_FILE" ]]; then
  echo "Usage: $0 <template-file>"
  exit 1
fi

# Extract the base name from the 'name:' line with printf in the template
# Looks for a Helm template line like: name: {{ printf "%s-%s" .Release.Name "something" }}
BASE_NAME=$(grep -oP 'name:\s*\{\{\s*printf\s*"%s-%s"\s*\.Release\.Name\s*"([^"]+)"' "$TEMPLATE_FILE" | head -1 | sed -E 's/.*"([^"]+)"/\1/')

# If BASE_NAME is empty, fallback to using the file name without extension
if [[ -z "$BASE_NAME" ]]; then
  BASE_NAME=$(basename "$TEMPLATE_FILE" .yaml)
fi
echo "Extracted BASE_NAME: $BASE_NAME"

# Construct the release name using the extracted base name
RELEASE_NAME="reporting-templates-${BASE_NAME}"

# Temporary file to store the processed template
TMP_FILE="/tmp/${RELEASE_NAME}.yaml"

# Remove all {{ ... }} Helm expressions and set the name field to the release name
sed 's/{{[^}]*}}//g' "$TEMPLATE_FILE" \
  | sed -E "s/^([[:space:]]*name:).*/\1 ${RELEASE_NAME}/" > "$TMP_FILE"

# Apply the processed template to the 'mojaloop' namespace using kubectl
kubectl -n mojaloop apply -f "$TMP_FILE"
