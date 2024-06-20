# A Simple Container with SSH Server

This image allows to run a simple SSH server in your CI self-hosted runners
infra. This server is needed for ci-storage tool to work.

1. Run this container on a central shared host of your self-hosted runners CI
   infra, together with other shared containers (like databases etc.).
2. Configure env variables and secrets accordingly:
   - `TZ` (optional): timezone name
3. Pass secrets:
   - `CI_STORAGE_PUBLIC_KEY` (optional): pass this secret or mount a file from
     host to `/run/secrets/CI_STORAGE_PUBLIC_KEY` to allow SSH access to this
     host from any ci-runner container which knows its private key
4. Optionally, mount some persistent volume to the storage directory, so it will
   survive the container restart.

Example for docker compose:

```yml
services:
   your-postgresql-container:
      ...   
   your-redis-container:
      ...   
   ci-storage:
      image: ghcr.io/dimikot/ci-storage:latest
      ports:
         - 10022:22/tcp
      environment:
         - TZ
      volumes:
         - ci-storage-mnt:/mnt
         - ~/.ssh/ci-storage.pub:/run/secrets/CI_STORAGE_PUBLIC_KEY
volumes:
   ci-storage-mnt:
      external: false
```

One ci-storage container may serve multiple GitHub repositories. Each of them
will have its own sub-directory (managed by ci-storage tool).

To enter the container, run e.g.:

```
docker compose exec ci-storage bash -l
```

See also https://github.com/dimikot/ci-storage
