set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Read a variable from .env (handles "KEY = value" and "KEY=value")
get_env() {
  grep -E "^\s*${1}\s*=" "$ENV_FILE" 2>/dev/null | sed -E 's/^[^=]+=\s*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r' | head -1
}

BUCKET="$(get_env MINECRAFT_SETTINGS_BUCKET)"
EFS_TO_S3_ARN="$(get_env DATASYNC_EFS_TO_S3_TASK_ARN)"
REGION="$(get_env SERVER_REGION)"
REGION="${REGION:-us-east-1}"

if [[ -z "$BUCKET" ]]; then
  echo "Set MINECRAFT_SETTINGS_BUCKET in .env to retrieve settings from S3."
  exit 1
fi

# Optionally run EFS→S3 DataSync first so S3 has the latest from the server
if [[ -n "$EFS_TO_S3_ARN" ]]; then
  echo "Running EFS→S3 DataSync to get latest files from server..."
  EXEC_ARN="$(aws datasync start-task-execution --task-arn "$EFS_TO_S3_ARN" --region "$REGION" --query 'TaskExecutionArn' --output text)"
  while true; do
    STATUS="$(aws datasync describe-task-execution --task-execution-arn "$EXEC_ARN" --region "$REGION" --query 'Status' --output text 2>/dev/null || true)"
    case "$STATUS" in
      SUCCESS) break ;;
      ERROR|UNKNOWN) echo "DataSync finished with status: $STATUS"; exit 1 ;;
      *) sleep 5 ;;
    esac
  done
  echo "DataSync complete."
fi

echo "Retrieving server settings from S3..."
if ! aws s3 cp "s3://$BUCKET/server.properties" "$SCRIPT_DIR/server.properties"; then
  echo "Run the EFS→S3 DataSync task first to copy server files from EFS to S3, then run retrieve.sh again."
  exit 1
fi
if ! aws s3 cp "s3://$BUCKET/whitelist.json" "$SCRIPT_DIR/whitelist.json"; then
  echo "Run the EFS→S3 DataSync task first to copy server files from EFS to S3, then run retrieve.sh again."
  exit 1
fi
echo "Done. server.properties and whitelist.json updated from S3."
