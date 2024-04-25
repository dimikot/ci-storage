# Auto-Scaling Self-Hosted Runner Image

You can build an image from this Dockerfile and use it to launch as many
self-hosted runners as you want. An example scenario:

1. Build an image based off this Dockerfile and publish it. You'll likely want
   to install some more software into that image (e.g. Node, Python etc.), so it
   may make sense to extend the base image with your own commands.
2. Run an AWS cluster (with e.g. spot instances with manual docker container
   boot) and use the image you just published. Configure its environment
   variables:
   - `GH_TOKEN` (required): PAT used to register the runner at github.com
   - `GH_REPOSITORY` (required): the repository this runner will serve
   - `GH_LABELS` (required): labels added to this runner
   - `TZ` (optional): timezone name
   - `FORWARD_HOST` (optional): some ports at localhost (provided in
     FORWARD_PORTS) will be forwarded to this host
   - `FORWARD_PORTS` (optional): a space-delimited list of forwarded TCP or UDP
     ports; any port number may be suffixed with "/udp" to forward UDP, e.g.
     "12345/udp"
   - `CI_STORAGE_HOST` (optional): the host which the initial ci-storage run
     will pull the data from; often times it is set to "127.0.0.1:10022" where
     10022 is an example of SSH port forwarded via FORWARD_HOST/FORWARD_PORTS
   - `DEBUG_SHUTDOWN_DELAY_SEC` (optional): a debug feature to test, how much
     time does the orchestrator give the container to gracefully shutdown before
     killing the container
3. Pass secrets:
   - `CI_STORAGE_PRIVATE_KEY` (optional): pass this secret or mount a file from
     host to run/secrets/CI_STORAGE_PRIVATE_KEY to configure SSH private key
     needed to access CI_STORAGE_HOST without a password
4. Set up auto-scaling rules based on e.g. the containers' CPU usage or
   ActiveRunnersPercent CloudWatch metric which the container publishes time to
   time. The running containers are safe to shut down at anytime if it's done
   gracefully and with high timeout (to let all the running workflow jobs finish
   there and de-register the runner).
5. And here comes the perf magic: when the container first boots, but before it
   becomes available for the jobs, it pre-initializes its work directory from
   ci-storage slots storage (see `CI_STORAGE_HOST`). So when a job is picked up,
   it already has its work directory pre-created and having most of the build
   artifacts of someone else. If the job then uses ci-storage GitHub action to
   restore the files from a slot, it will be very quick, because most of the
   files are already there.

The container in this Dockerfile serves only one particular GitHub repository
(controlled by `GH_REPOSITORY` environment variable at boot time). To serve
different repositories, boot different containers.

We also expose a naming convention on extra entrypoint files to be possibly
defined in your own derived Dockerfile. When extending this image, one can put
custom files like /root/entrypoint.*.sh (to be run as "root") or
/home/guest/entrypoint.*.sh (to be run as "guest"). Those files will be
automatically picked up and executed.

To enter the container, run e.g.:

```
docker compose exec ci-runner bash -l
```

It will automatically change the user and current directory to /home/guest
(without "-l", it will run a root shell session).

See also https://github.com/dimikot/ci-storage
