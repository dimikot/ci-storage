# A Simple Container with SSH Server

Build an image from this Dockerfile to launch a simple SSH server with rsync.

- Pre-creates /home/user/ci-storage directory.
- Copies public key in CI_STORAGE_HOST_PUBLIC_KEY to user's authorized_keys.

One "host" container may serve multiple GitHub repositories. Each of them will
have own directory in /home/user/ci-storage (managed by ci-storage tool).

See also https://github.com/dimikot/ci-storage
