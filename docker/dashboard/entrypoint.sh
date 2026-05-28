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

exec nginx -g "daemon off;"
