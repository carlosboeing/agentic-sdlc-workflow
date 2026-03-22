#!/usr/bin/env bash
# _common.sh -- Shared helpers for the server PM adapter.
#
# Provides server URL discovery, health check, and curl wrappers.
# Sourced by all other server adapter modules.
#
# URL discovery order:
#   1. WORKFLOW_SERVER_URL environment variable (highest priority)
#   2. .agentic-workflow/server.port file (port number -> http://127.0.0.1:<port>)
#
# Usage: source this file; do not execute directly.

# Idempotency guard
if [ -n "${_SERVER_COMMON_LOADED:-}" ]; then
  return 0 2>/dev/null || exit 0
fi
_SERVER_COMMON_LOADED=1

# Resolve the workflow directory for port file lookup.
# _SERVER_WORKFLOW_DIR can be overridden for testing.
_SERVER_WORKFLOW_DIR="${_SERVER_WORKFLOW_DIR:-${CFG_WORKFLOW_DIR:-.agentic-workflow}}"

# Default curl timeout for API calls (seconds)
_SERVER_CURL_TIMEOUT="${_SERVER_CURL_TIMEOUT:-5}"

# Health check timeout (shorter for quick fail)
_SERVER_HEALTH_TIMEOUT="${_SERVER_HEALTH_TIMEOUT:-2}"

# ---------------------------------------------------------------------------
# Server URL discovery
# ---------------------------------------------------------------------------

# _workflow_server_url -- Print the server base URL to stdout.
# Returns 0 on success, 1 if no server URL can be determined.
_workflow_server_url() {
  # Priority 1: environment variable
  if [ -n "${WORKFLOW_SERVER_URL:-}" ]; then
    echo "$WORKFLOW_SERVER_URL"
    return 0
  fi

  # Priority 2: port file
  local port_file="$_SERVER_WORKFLOW_DIR/server.port"
  if [ -f "$port_file" ]; then
    local port
    port=$(cat "$port_file" 2>/dev/null)
    if [ -n "$port" ]; then
      echo "http://127.0.0.1:$port"
      return 0
    fi
  fi

  echo "ERROR: Cannot determine workflow server URL. Set WORKFLOW_SERVER_URL or ensure $_SERVER_WORKFLOW_DIR/server.port exists." >&2
  return 1
}

# ---------------------------------------------------------------------------
# Health check
# ---------------------------------------------------------------------------

# _server_health_check -- Returns 0 if the server is running and healthy.
# Uses GET /api/health with a short timeout.
_server_health_check() {
  local url
  url=$(_workflow_server_url 2>/dev/null) || return 1

  local http_code
  http_code=$(curl -s -o /dev/null -w "%{http_code}" \
    --connect-timeout "$_SERVER_HEALTH_TIMEOUT" \
    --max-time "$_SERVER_HEALTH_TIMEOUT" \
    "$url/api/health" 2>/dev/null) || return 1

  [ "$http_code" = "200" ]
}

# ---------------------------------------------------------------------------
# curl wrappers
# ---------------------------------------------------------------------------

# _server_pm_curl_get <path> -- GET request, prints response body.
# Returns 0 on 2xx, 1 on error or non-2xx.
_server_pm_curl_get() {
  local path="$1"
  local url
  url=$(_workflow_server_url) || return 1

  local response http_code body
  response=$(curl -s -w "\n%{http_code}" \
    --connect-timeout "$_SERVER_CURL_TIMEOUT" \
    --max-time "$_SERVER_CURL_TIMEOUT" \
    "$url$path" 2>/dev/null) || {
    echo "ERROR: curl failed for GET $path" >&2
    return 1
  }

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  case "$http_code" in
    2[0-9][0-9])
      echo "$body"
      return 0
      ;;
    *)
      echo "ERROR: GET $path returned HTTP $http_code: $body" >&2
      return 1
      ;;
  esac
}

# _server_pm_curl_post <path> <json-body> -- POST request with JSON body.
# Prints response body. Returns 0 on 2xx, 1 on error.
_server_pm_curl_post() {
  local path="$1"
  local json_body="$2"
  local url
  url=$(_workflow_server_url) || return 1

  local response http_code body
  response=$(curl -s -w "\n%{http_code}" \
    --connect-timeout "$_SERVER_CURL_TIMEOUT" \
    --max-time "$_SERVER_CURL_TIMEOUT" \
    -X POST \
    -H "Content-Type: application/json" \
    -d "$json_body" \
    "$url$path" 2>/dev/null) || {
    echo "ERROR: curl failed for POST $path" >&2
    return 1
  }

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  case "$http_code" in
    2[0-9][0-9])
      echo "$body"
      return 0
      ;;
    *)
      echo "ERROR: POST $path returned HTTP $http_code: $body" >&2
      return 1
      ;;
  esac
}

# _server_pm_curl_patch <path> <json-body> -- PATCH request with JSON body.
# Prints response body. Returns 0 on 2xx, 1 on error.
_server_pm_curl_patch() {
  local path="$1"
  local json_body="$2"
  local url
  url=$(_workflow_server_url) || return 1

  local response http_code body
  response=$(curl -s -w "\n%{http_code}" \
    --connect-timeout "$_SERVER_CURL_TIMEOUT" \
    --max-time "$_SERVER_CURL_TIMEOUT" \
    -X PATCH \
    -H "Content-Type: application/json" \
    -d "$json_body" \
    "$url$path" 2>/dev/null) || {
    echo "ERROR: curl failed for PATCH $path" >&2
    return 1
  }

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  case "$http_code" in
    2[0-9][0-9])
      echo "$body"
      return 0
      ;;
    *)
      echo "ERROR: PATCH $path returned HTTP $http_code: $body" >&2
      return 1
      ;;
  esac
}

# _server_pm_curl_delete <path> -- DELETE request.
# Prints response body. Returns 0 on 2xx, 1 on error.
_server_pm_curl_delete() {
  local path="$1"
  local url
  url=$(_workflow_server_url) || return 1

  local response http_code body
  response=$(curl -s -w "\n%{http_code}" \
    --connect-timeout "$_SERVER_CURL_TIMEOUT" \
    --max-time "$_SERVER_CURL_TIMEOUT" \
    -X DELETE \
    "$url$path" 2>/dev/null) || {
    echo "ERROR: curl failed for DELETE $path" >&2
    return 1
  }

  http_code=$(echo "$response" | tail -1)
  body=$(echo "$response" | sed '$d')

  case "$http_code" in
    2[0-9][0-9])
      echo "$body"
      return 0
      ;;
    *)
      echo "ERROR: DELETE $path returned HTTP $http_code: $body" >&2
      return 1
      ;;
  esac
}

# ---------------------------------------------------------------------------
# JSON escaping helper
# ---------------------------------------------------------------------------

# _server_escape_json <string> -- Escape a string for safe JSON embedding.
# Handles all JSON control characters per RFC 8259: backslash, double-quote,
# newline, tab, carriage return, backspace, and form feed.
_server_escape_json() {
  printf '%s' "$1" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read())[1:-1], end='')"
}
