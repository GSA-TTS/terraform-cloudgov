#!/bin/sh

# Exit if any step fails
set -e

eval "$(jq -r '@sh "GITREF=\(.gitref) ORG=\(.org) REPO=\(.repo) SRC_FOLDER=\(.src_folder)"')"

popdir="$(pwd)"

# Portable construct so this will work everywhere
# https://unix.stackexchange.com/a/84980
tmpdir=$(mktemp -d 2>/dev/null || mktemp -d -t 'mytmpdir')
cd "$tmpdir"

# Grab a copy of the zip file for the specified ref
curl -s -L "https://github.com/${ORG}/${REPO}/archive/${GITREF}.zip" --output local.zip

# Get the folder that curl will download, usually looks like {repo_name}-{branch_name}/
zip_folder=$(unzip -l local.zip | awk '/\/$/ {print $4}' | awk -F'/' '{print $1}' | sort -u)

# Zip up just the app for pushing under different circumstances.
# if $SRC_FOLDER = "", then we want to look for the app in the root of the repo {repo_name}-{branch_name}/.
if [ -z "$SRC_FOLDER" ]; then
  unzip -q -u local.zip "$zip_folder/*"
  cd "$zip_folder/" && zip -q -r -o -X "${popdir}/app.zip" ./
else
# if $SRC_FOLDER = "some/folder" then we want to look for the app in that path {repo_name}-{branch_name}/{src_code_folder}/.
  unzip -q -u local.zip "$zip_folder/$SRC_FOLDER/*"
  cd "$zip_folder/$SRC_FOLDER/" && zip -q -r -o -X "${popdir}/app.zip" ./
fi


# Tell Terraform where to find it
cat << EOF
{ "path": "app.zip" }
EOF
