# A Simple Container with SSH Server

1. Build an image from this Dockerfile to launch a simple SSH server with rsync.
2. Configure env variables and secrets accordingly:
   - `TZ` (optional): timezone name
3. Pass secrets:
   - `CI_STORAGE_PUBLIC_KEY` (optional): pass this secret or mount a file from
     host to `/run/secrets/CI_STORAGE_PUBLIC_KEY` to allow SSH access to this
     host from any ci-runner container which knows its private key
4. Mount some persistent storage (e.g. a EBS volume) to `/mnt`, so it survives
   the container restart.

One "storage" container may serve multiple GitHub repositories. Each of them
will have own directory in /mnt (managed by ci-storage tool).

See also https://github.com/dimikot/ci-storage
