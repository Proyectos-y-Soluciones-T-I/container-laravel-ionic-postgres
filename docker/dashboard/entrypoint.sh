#!/bin/sh
# Resolve the host IP at container start time.
# host.docker.internal resolves to IPv6 on Docker Desktop for Windows,
# which causes "Network unreachable" when nginx tries to proxy to host ports.
# Instead we use the default gateway of the container's network, which is
# always the host on Docker Desktop and Docker Engine with bridge networks.

HOST_IP=$(ip route show default | awk '/default/ { print $3 }')

echo "dashboard: host IP resolved to $HOST_IP"

# Substitute HOST_IP in the nginx config template and write the final config.
sed "s/\$HOST_IP/$HOST_IP/g" /etc/nginx/conf.d/default.conf.template \
  > /etc/nginx/conf.d/default.conf

# ── Build env-data.json for the .env generator ──────────────────────
ENV_DATA_FILE=/usr/share/nginx/html/env-data.json

# Shared section from /repo/.env
if [ -f /repo/.env ]; then
  SHARED=$(awk '
    /^#/ { next }
    /^$/ { next }
    {
      eq = index($0, "=");
      if (eq == 0) next;
      key = substr($0, 1, eq - 1);
      val = substr($0, eq + 1);
      # ponytail: include \r in trim (CRLF Windows .env); strip inline " #..."
      # comment after value (best-effort, breaks quoted values containing #)
      gsub(/^[ \t\r]+|[ \t\r]+$/, "", key);
      gsub(/^[ \t\r]+|[ \t\r]+$/, "", val);
      sub(/[ \t]+#.*$/, "", val);
      gsub(/\\/, "\\\\", val);
      gsub(/"/, "\\\"", val);
      printf "\"%s\": \"%s\",", key, val;
    }
  ' /repo/.env | sed 's/,$//')
  SHARED_JSON="{${SHARED}}"
else
  SHARED_JSON="{}"
fi

# Projects section from /repo/envs/*.env
N_PROJECTS=0
PROJECTS_JSON=""
if [ -d /repo/envs ]; then
  for f in /repo/envs/*.env; do
    [ -f "$f" ] || continue
    N_PROJECTS=$((N_PROJECTS + 1))
    PROJ=$(basename "$f" .env)
    ENTRIES=$(awk '
      /^#/ { next }
      /^$/ { next }
      {
        eq = index($0, "=");
        if (eq == 0) next;
        key = substr($0, 1, eq - 1);
        val = substr($0, eq + 1);
        # ponytail: include \r in trim (CRLF Windows .env); strip inline " #..."
        # comment after value (best-effort, breaks quoted values containing #)
        gsub(/^[ \t\r]+|[ \t\r]+$/, "", key);
        gsub(/^[ \t\r]+|[ \t\r]+$/, "", val);
        sub(/[ \t]+#.*$/, "", val);
        gsub(/\\/, "\\\\", val);
        gsub(/"/, "\\\"", val);
        printf "\"%s\": \"%s\",", key, val;
      }
    ' "$f" | sed 's/,$//')
    PROJECTS_JSON="${PROJECTS_JSON}\"${PROJ}\": {${ENTRIES}},"
  done
fi

if [ -z "$PROJECTS_JSON" ]; then
  PROJECTS_JSON="{}"
else
  PROJECTS_JSON=$(echo "$PROJECTS_JSON" | sed 's/,$//')
  PROJECTS_JSON="{${PROJECTS_JSON}}"
fi

printf '{"shared":%s,"projects":%s}\n' "$SHARED_JSON" "$PROJECTS_JSON" > "$ENV_DATA_FILE"
echo "dashboard: wrote env-data.json ($(wc -c < "$ENV_DATA_FILE" 2>/dev/null || echo 0) bytes), ${N_PROJECTS} projects"

exec nginx -g "daemon off;"
