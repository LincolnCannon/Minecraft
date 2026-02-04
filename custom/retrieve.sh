set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ENV_FILE="$SCRIPT_DIR/.env"

# Read a variable from .env (handles "KEY = value" and "KEY=value")
get_env() {
  grep -E "^\s*${1}\s*=" "$ENV_FILE" 2>/dev/null | sed -E 's/^[^=]+=\s*//' | sed 's/^[[:space:]]*//;s/[[:space:]]*$//' | tr -d '\r' | head -1
}

BUCKET="$(get_env MINECRAFT_SETTINGS_BUCKET)"

if [[ -z "$BUCKET" ]]; then
  echo "Set MINECRAFT_SETTINGS_BUCKET in .env to retrieve settings from S3."
  exit 1
fi

echo "Retrieving server settings from S3..."
aws s3 cp "s3://$BUCKET/minecraft/server.properties" "$SCRIPT_DIR/server.properties"
aws s3 cp "s3://$BUCKET/minecraft/whitelist.json" "$SCRIPT_DIR/whitelist.json"
echo "Done. server.properties and whitelist.json updated from S3."
