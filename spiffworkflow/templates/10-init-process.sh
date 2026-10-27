#!/usr/bin/env bash
set -euo pipefail

# Ensure base .profile is sourced (not automatically sourced before profile.d scripts!)
if [ -f /home/vcap/app/.profile ]; then
  # shellcheck disable=SC1091
  source /home/vcap/app/.profile || true
fi

if [[ "${CF_INSTANCE_INDEX:-0}" != "0" ]]; then
  echo "Skipping bootstrap process for app at index ${CF_INSTANCE_INDEX} by unsetting env variable SPIFFWORKFLOW_BACKEND_BOOTSTRAP_PROCESS_MODEL"
  unset SPIFFWORKFLOW_BACKEND_BOOTSTRAP_PROCESS_MODEL
  return 0 2>/dev/null || exit 0
fi
