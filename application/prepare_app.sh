#!/bin/sh

# Exit if any step fails
set -e

eval "$(jq -r '@sh "GITREF=\(.gitref) ORG=\(.org) REPO=\(.repo) SRC_FOLDER=\(.src_folder)"')"

popdir=$(pwd)

# Portable construct so this will work everywhere
# https://unix.stackexchange.com/a/84980
tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')
cd "$tmpdir"

# Grab a copy of the zip file for the specified ref
curl -s -L "https://github.com/${ORG}/${REPO}/archive/${GITREF}.zip" --output local.zip

zip_folder=$(unzip -l local.zip | awk '/\/$/ {print $4}' | awk -F'/' '{print $1}' | sort -u)
# Zip up just the $REPO-$branch/ subdirectory for pushing
# Before zip stage, run [ npm ci --production | npm run build ] in /backend/ to get the compiled assets for the site in /static/compiled/
unzip -q -u local.zip \*"$zip_folder/$SRC_FOLDER/*"\*
cd "${tmpdir}/$zip_folder/$SRC_FOLDER/" &&
npm ci --production --silent --no-progress &&
npm run build > '/dev/null' 2>&1 &&
zip -r -o -X "${popdir}/app.zip" ./ > /dev/null

# Tell Terraform where to find it
cat << EOF
{ "path": "app.zip" }
EOF
