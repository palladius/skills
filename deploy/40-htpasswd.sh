#!/bin/sh
# Generates /etc/nginx/.htpasswd from BASIC_AUTH_USER / BASIC_AUTH_PASS at container start.
# Fails closed: with no password set, nginx refuses to start rather than serve anything.
set -eu
: "${BASIC_AUTH_USER:=ricc}"
if [ -z "${BASIC_AUTH_PASS:-}" ]; then
  echo "FATAL: BASIC_AUTH_PASS is not set — refusing to serve a private site without auth" >&2
  exit 1
fi
htpasswd -cbB /etc/nginx/.htpasswd "$BASIC_AUTH_USER" "$BASIC_AUTH_PASS"
chmod 640 /etc/nginx/.htpasswd
echo "htpasswd ready for user '$BASIC_AUTH_USER'"
