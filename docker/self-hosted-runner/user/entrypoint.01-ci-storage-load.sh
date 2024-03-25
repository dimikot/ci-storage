#!/bin/bash
#
# Loads the initial content of work directory from ci-storage host.
#
set -u -e

echo "$CI_STORAGE_HOST" > ci-storage-host

local_dir=~/actions-runner/_work/${GH_REPOSITORY##*/}/${GH_REPOSITORY##*/}

if [[ "$CI_STORAGE_HOST" != "" ]]; then
  mkdir -p "$local_dir"
  ci-storage load \
    --storage-host="$CI_STORAGE_HOST" \
    --storage-dir="~/ci-storage/$GH_REPOSITORY" \
    --slot-id="?" \
    --local-dir="$local_dir"
fi

cat <<EOT > ~/.bash_profile
#!/bin/bash
cd "$local_dir" 2>/dev/null || true
EOT
