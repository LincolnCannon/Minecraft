set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Optional first argument: cdk | custom | web (default: all)
MODE="${1:-all}"
case "$MODE" in
  cdk|custom|web|all) ;;
  *)
    echo "Usage: $0 [cdk|custom|web]" >&2
    echo "  (no argument = deploy all)" >&2
    echo "  cdk    = CDK stacks only" >&2
    echo "  custom = server.properties + whitelist.json to EFS (S3 + DataSync)" >&2
    echo "  web    = start page (web/index.html) to S3" >&2
    exit 1
    ;;
esac

# Read a variable from .env (handles "KEY = value" and "KEY=value")
get_env() {
  grep -E "^\s*${1}\s*=" "$ENV_FILE" 2>/dev/null | sed -E 's/^[^=]+=\s*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r' | head -1
}

if [[ "$MODE" == "cdk" || "$MODE" == "all" ]]; then
  # --- CDK deploy ---
  cd "$REPO_ROOT/cdk"
  cp "$ENV_FILE" .env
  npm run build
  npm run deploy
fi

if [[ "$MODE" == "custom" || "$MODE" == "all" ]]; then
  # --- Optional: deploy server.properties and whitelist.json to EFS via S3 + DataSync ---
  BUCKET="$(get_env MINECRAFT_SETTINGS_BUCKET)"
  TASK_ARN="$(get_env DATASYNC_S3_TO_EFS_TASK_ARN)"
  REGION="$(get_env SERVER_REGION)"
  REGION="${REGION:-us-east-1}"

  if [[ -n "$BUCKET" && -n "$TASK_ARN" ]]; then
    echo "Deploying server settings to EFS (S3 → DataSync)..."
    aws s3 cp "$SCRIPT_DIR/server.properties" "s3://$BUCKET/server.properties"
    aws s3 cp "$SCRIPT_DIR/whitelist.json" "s3://$BUCKET/whitelist.json"
    EXEC_ARN="$(aws datasync start-task-execution --task-arn "$TASK_ARN" --region "$REGION" --query 'TaskExecutionArn' --output text)"
    echo "DataSync task started. Waiting for sync to EFS..."
    while true; do
      STATUS="$(aws datasync describe-task-execution --task-execution-arn "$EXEC_ARN" --region "$REGION" --query 'Status' --output text 2>/dev/null || true)"
      case "$STATUS" in
        SUCCESS) echo "Settings synced to EFS successfully."; break ;;
        ERROR|UNKNOWN) echo "DataSync finished with status: $STATUS"; exit 1 ;;
        *) sleep 5 ;;
      esac
    done
  else
    echo "Skipping settings deploy (set MINECRAFT_SETTINGS_BUCKET and DATASYNC_S3_TO_EFS_TASK_ARN in .env to push server.properties and whitelist.json to EFS)."
  fi
fi

if [[ "$MODE" == "web" || "$MODE" == "all" ]]; then
  # --- Optional: deploy start webpage to S3 (minecraft-start.example.com) ---
  START_PAGE_BUCKET="$(get_env START_PAGE_BUCKET)"
  if [[ -n "$START_PAGE_BUCKET" ]]; then
    echo "Deploying start webpage to S3..."
    aws s3 cp "$REPO_ROOT/web/index.html" "s3://$START_PAGE_BUCKET/index.html" \
      --content-type "text/html" \
      --cache-control "max-age=60"
    echo "Start webpage deployed to s3://$START_PAGE_BUCKET/"
  else
    echo "Skipping start page deploy (set START_PAGE_BUCKET in .env to push web/index.html to your minecraft-start S3 bucket)."
  fi
fi

<<comment
Run retrieve.sh to get the latest server.properties and whitelist.json from S3 -- always run this first and confirm desired settings.
Run deploy.sh to push the latest server.properties and whitelist.json to EFS -- always run this last.
Set START_PAGE_BUCKET to your minecraft-start S3 bucket name to deploy web/index.html on each run.
General Instructions: https://github.com/doctorray117/minecraft-ondemand
Delete Instructions: delete the hosted zone A record in Route 53 first, then run "npm run destroy"
Settings Tasks: https://us-east-1.console.aws.amazon.com/datasync/home?region=us-east-1#/tasks
Settings Files: https://us-east-1.console.aws.amazon.com/s3/buckets/minecraft.metacannon.net?region=us-east-1&bucketType=general&tab=objects
UUID Lookup: https://mcuuid.net/
comment