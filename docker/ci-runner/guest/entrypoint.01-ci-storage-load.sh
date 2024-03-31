#!/bin/bash
#
# Loads the initial content of work directory from storage host.
#
set -u -e

echo "$CI_STORAGE_HOST" > ci-storage-host

local_dir=/mnt/${GH_REPOSITORY##*/}/${GH_REPOSITORY##*/}

if [[ "$CI_STORAGE_HOST" != "" ]]; then
  mkdir -p "$local_dir"
  ci-storage load \
    --storage-host="$CI_STORAGE_HOST" \
    --storage-dir="/mnt/$GH_REPOSITORY" \
    --slot-id="*" \
    --local-dir="$local_dir"
fi

cat <<EOT > ~/.bash_profile
#!/bin/bash
cd "$local_dir" 2>/dev/null || true
EOT
