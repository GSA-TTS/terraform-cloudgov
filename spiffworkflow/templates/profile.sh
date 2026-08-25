#!/usr/bin/env bash
export PYTHONPATH="/home/vcap/app:/home/vcap/app/src:/home/vcap/deps/0/python:/home/vcap/deps/0"

# Get the postgres URI from the service binding. (SQL Alchemy insists on "postgresql://".🙄)
export SPIFFWORKFLOW_BACKEND_DATABASE_URI=$( echo ${VCAP_SERVICES:-} | jq -r '.["aws-rds"][].credentials.uri' | sed -e s/postgres/postgresql/ )

# Set the HTTPS_PROXY
if [ -n "$PROXYROUTE" ]; then
  echo "Setting the https proxy"
  export HTTPS_PROXY="$PROXYROUTE"
  export NO_PROXY="apps.internal"  # For internal traffic
fi

# Check if the backend queue service is set and is a type that we support (it supplies a .credentials.uri that's usable as is)
if [ -n "${QUEUE_SERVICE_NAME:-}" ]; then
  QUEUE_URI=$(echo "${VCAP_SERVICES}" | jq -r --arg name "$QUEUE_SERVICE_NAME" '
    to_entries[]
    | select(.value[0].instance_name == $name)
    | .value[0].credentials.uri // empty
  ')
  # Force TLS if a non-TLS Redis URI is provided (convert redis:// -> rediss://)
  if [ -n "$QUEUE_URI" ] && [ "${QUEUE_URI#redis://}" != "$QUEUE_URI" ]; then
    QUEUE_URI="rediss://${QUEUE_URI#redis://}"
  fi
  # If we have a rediss URL but no ssl_cert_reqs parameter, append one so Celery's Redis backend
  # doesn't raise: "A rediss:// URL must have parameter ssl_cert_reqs ..."
  # Allow override via QUEUE_SSL_CERT_REQS env var (values: CERT_REQUIRED, CERT_OPTIONAL, CERT_NONE).
  QUEUE_SSL_CERT_REQS_VALUE="${QUEUE_SSL_CERT_REQS:-CERT_OPTIONAL}"
  if [ -n "$QUEUE_URI" ] && [ "${QUEUE_URI#rediss://}" != "$QUEUE_URI" ] && ! echo "$QUEUE_URI" | grep -qi 'ssl_cert_reqs='; then
    if echo "$QUEUE_URI" | grep -q '?'; then
      QUEUE_URI="${QUEUE_URI}&ssl_cert_reqs=${QUEUE_SSL_CERT_REQS_VALUE}"
    else
      QUEUE_URI="${QUEUE_URI}?ssl_cert_reqs=${QUEUE_SSL_CERT_REQS_VALUE}"
    fi
  fi
  if [ -n "$QUEUE_URI" ]; then
    # Enable Celery for background processing
    export SPIFFWORKFLOW_BACKEND_CELERY_ENABLED=true
    export SPIFFWORKFLOW_BACKEND_CELERY_BROKER_URL="$QUEUE_URI"
    export SPIFFWORKFLOW_BACKEND_CELERY_RESULT_BACKEND="$QUEUE_URI"

    # Enable the metadata backfill feature
    SPIFFWORKFLOW_BACKEND_PROCESS_INSTANCE_METADATA_BACKFILL_ENABLED=true
  else 
    echo "WARNING: QUEUE_SERVICE_NAME is set but no matching service found in VCAP_SERVICES; skipping configuration"
  fi
fi
