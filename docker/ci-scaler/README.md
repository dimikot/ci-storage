# A Scaler Service for Runners

This image:

1. Reacts on GitHub webhook events by adding more runner instances to an
   auto-scaling group.
2. Maintains the constant pool of idle runners.
3. De-registers offline runners if they appear.
4. Publishes CloudWatch statistics.

To use:

1. Run this container on a central shared host of your self-hosted runners CI
   infra, together with other shared containers (like databases etc.).
2. Configure env variables and secrets accordingly:
   - `GH_TOKEN`: PAT at github.com to work with repositories in ASGS
   - `ASGS`: space delimited list of auto-scaling specs; format of each item:
     "{owner}/{repo}:{label}:{asg_name}"
   - `DOMAIN`: domain of API Gateway which listens for GitHub webhook
     requests via HTTPS and forwards all requests to this container's port 8088
   - `TZ` (optional): timezone name

Example for docker compose:

```yml
services:
      ...   
   ci-scaler:
      image: ghcr.io/dimikot/ci-scaler:latest
      ports:
         - 18088:8088/tcp
      environment:
        - GH_TOKEN
        - ASGS
        - DOMAIN
        - TZ
```

One ci-scaler container may serve multiple GitHub repositories.

See also https://github.com/dimikot/ci-storage
