#!/bin/bash
set -e

# Collect inputs and assign to friendly names
org="$1"; space="$2";
http_user="$3"; http_pass="$4";
nr_key="$5"; nr_api="$6";
logdrain="$7"; app_name="$8";
s3_name="$9";

# Since cf cups does not support --wait, we use this as a basic way to ensure
# that the api has caught up with things.
wait_for_api(){
    echo "Sleeping for CF API..."
    sleep 10
 }

logshipper_creds() {
    cf cups logshipper-creds -p "'{\"HTTP_USER\":\"$http_user\",\"HTTP_PASS\":\"$http_pass\"}'"
}

logshipper_new_relic_creds() {
    cf cups logshipper-new-relic-creds -p "'{\"NEW_RELIC_LICENSE_KEY\":\"$nr_key\",\"NEW_RELIC_LOGS_ENDPOINT\":\"$nr_api\"}'"
}

logdrain() {
    cf cups logdrain -l "$logdrain"
}

bind_services() {
    cf bind-service "$app_name" logshipper-creds --wait &&
    cf bind-service "$app_name" logshipper-new-relic-creds --wait &&
    cf bind-service "$app_name" logdrain --wait &&
    cf bind-service "$app_name" "$s3_name" --wait &&
    cf restage "$app_name" > /dev/null 2>&1
}

cf t -o "$org" -s "$space"
echo "Creating Logshipper User Provided Service..."
logshipper_creds && wait_for_api
echo "Creating New Relic User Provided Service..."
logshipper_new_relic_creds && wait_for_api
echo "Creating Logdrain Service..."
logdrain && wait_for_api
echo "Binding Services to app..."
bind_services
