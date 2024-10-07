#!/bin/bash
#
# Loads the initial content of work directory from storage host.
#
set -u -e

echo "$CI_STORAGE_HOST" > ci-storage-host

# For some reason, the default GitHub Runner's work directory is
# "$WORK_DIR/{repo-name}/{repo-name}" (i.e. repo-name is repeated twice).
local_dir=$WORK_DIR/${GH_REPOSITORY##*/}/${GH_REPOSITORY##*/}

mkdir -p "$local_dir"
cat <<EOT > ~/.bash_profile
#!/bin/bash
cd "$local_dir" 2>/dev/null || true
EOT

if [[ "$CI_STORAGE_HOST" != "" && -f ~/.ssh/id_rsa ]]; then
  say "Running the initial \"ci-storage load\" for $local_dir..."
  ci-storage load \
    --storage-host="$CI_STORAGE_HOST" \
    --storage-dir="$WORK_DIR/$GH_REPOSITORY/$(realpath "$local_dir" | tr / _)" \
    --slot-id="*" \
    --local-dir="$local_dir" \
    & export CI_STORAGE_PID=$!
fi
