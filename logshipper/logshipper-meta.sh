#!/bin/sh
set -e

# Collect inputs and assign to friendly names
org="$1"; space="$2";
http_user="$3"; http_pass="$4";
nr_key="$5"; nr_api="$6";
logdrain="$7";

wait_for_api(){
    echo "Sleeping for CF API..."
    sleep 10
}

logshipper_creds() {
    if [ -n "$(cf service logshipper-creds)" ] ; then :
    else
        cf cups logshipper-creds -p "'{\"HTTP_USER\":\"$http_user\",\"HTTP_PASS\":\"$http_pass\"}'"
    fi
}

logshipper_new_relic_creds() {
    if [ -n "$(cf service logshipper-new-relic-creds)" ] ; then :
    else
        cf cups logshipper-new-relic-creds -p "'{\"NEW_RELIC_LICENSE_KEY\":\"$nr_key\",\"NEW_RELIC_LOGS_ENDPOINT\":\"$nr_api\"}'"
    fi
}

logdrain() {
    if [ -n "$(cf service logdrain)" ] ; then :
    else
        cf cups logdrain -l "$logdrain"
    fi
}

cf t -o "$org" -s "$space"
echo "Creating Logshipper User Provided Service..."
logshipper_creds && wait_for_api
echo "Creating New Relic User Provided Service..."
logshipper_new_relic_creds && wait_for_api
echo "Creating Logdrain Service..."
logdrain && wait_for_api
