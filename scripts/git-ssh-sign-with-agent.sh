#!/usr/bin/env bash
set -euo pipefail

find_agent() {
  local candidate

  if [[ -n "${SSH_AUTH_SOCK:-}" && -S "${SSH_AUTH_SOCK}" ]]; then
    if SSH_AUTH_SOCK="${SSH_AUTH_SOCK}" ssh-add -l >/dev/null 2>&1; then
      printf '%s\n' "${SSH_AUTH_SOCK}"
      return 0
    fi
  fi

  while IFS= read -r candidate; do
    [[ -S "${candidate}" ]] || continue
    if SSH_AUTH_SOCK="${candidate}" ssh-add -l >/dev/null 2>&1; then
      printf '%s\n' "${candidate}"
      return 0
    fi
  done < <(
    {
      find /tmp -maxdepth 1 -type s -name 'vscode-ssh-auth-*.sock' -printf '%T@ %p\n' 2>/dev/null || true
      find /tmp -maxdepth 2 -type s -path '/tmp/ssh-*/agent.*' -printf '%T@ %p\n' 2>/dev/null || true
    } | sort -rn | awk '{print $2}'
  )

  return 1
}

agent_sock="$(find_agent)" || {
  echo "No usable SSH agent socket found for Git SSH signing." >&2
  exit 1
}

export SSH_AUTH_SOCK="${agent_sock}"
exec /usr/bin/ssh-keygen "$@"
