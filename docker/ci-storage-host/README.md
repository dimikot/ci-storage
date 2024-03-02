# A Simple Container with SSH Server

Build an image from this Dockerfile to launch a simple SSH server with rsync.

- Pre-creates /home/user/ci-storage directory.
- Copies public key in CI_STORAGE_HOST_PUBLIC_KEY to user's authorized_keys.

One ci-storage-host contain may serve multiple GitHub repositories. Each of them
will have own directory in /home/user/ci-storage (managed by ci-storage tool).
