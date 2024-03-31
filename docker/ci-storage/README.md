# A Simple Container with SSH Server

1. Build an image from this Dockerfile to launch a simple SSH server with rsync.
2. Pass secret `CI_STORAGE_PUBLIC_KEY` which will be copied to
   `/home/guest/.ssh/authorized_keys`.
3. Mount some persistent storage (e.g. a EBS volume) to `/home/guest/ci-storage`,
   so it survives the container restart.

One "storage" container may serve multiple GitHub repositories. Each of them
will have own directory in /home/guest/ci-storage (managed by ci-storage tool).

See also https://github.com/dimikot/ci-storage
