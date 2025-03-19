#!/bin/sh
set -e

# Collect inputs and assign to friendly names
org="$1"; space="$2";
http_user="$3"; http_pass="$4";
nr_key="$5"; nr_api="$6";
logdrain="$7";
app_name="$8";

logshipper_creds() {
    if [ -n "$(cf service logshipper-creds)" ] ; then :
    else
        cf cups logshipper-creds -p "'{\"HTTP_USER\":\"$http_user\",\"HTTP_PASS\":\"$http_pass\"}'" --wait
    fi
}

logshipper_new_relic_creds() {
    if [ -n "$(cf service logshipper-new-relic-creds)" ] ; then :
    else
        cf cups logshipper-new-relic-creds -p "'{\"NEW_RELIC_LICENSE_KEY\":\"$nr_key\",\"NEW_RELIC_LOGS_ENDPOINT\":\"$nr_api\"}'" --wait
    fi
}

logdrain() {
    if [ -n "$(cf service logdrain)" ] ; then :
    else
        cf cups logdrain -l "$logdrain" --wait
    fi
}

bind_services() {
    cf bind-service "$app_name" logshipper-creds --wait &&
    cf bind-service "$app_name" logshipper-new-relic-creds --wait &&
    cf bind-service "$app_name" logdrain --wait &&
    cf restage "$app_name" --wait
}

cf t -o "$org" -s "$space"
echo "Creating Logshipper User Provided Service..."
logshipper_creds
echo "Creating New Relic User Provided Service..."
logshipper_new_relic_creds
echo "Creating Logdrain Service..."
logdrain
echo "Binding Services to app..."
bind_services
