# Auto-Scaling Self-Hosted Runner Image

You can build an image from this Dockerfile and use it to launch as many
self-hosted runners as you want. An example scenario:

1. Build an image based off this Dockerfile and publish it. You'll likely want
   to install some more software into that image (e.g. Node, Python etc.), so it
   may make sense to extend the base image with your own commands.
2. Run AWS ECS cluster (with e.g. AWS ECS or spot instances with manual docker
   container boot) and use the image you just published. Configure its
   environment variables accordingly: `GH_REPOSITORY`, `GH_LABELS`, `GH_TOKEN`
   etc. - see the full list in `entrypoint.00-validate.sh`.
3. Set up auto-scaling rules based on the containers' CPU usage. The running
   containers are safe to shut down at anytime if it's done gracefully and with
   high timeout (to let all the running workflow jobs finish there and
   de-register the runner).
4. And here comes the perf magic: when the container first boots, but before it
   becomes available for the jobs, it pre-initializes its work directory from
   ci-storage slots storage (see `CI_STORAGE_HOST`). So when a job is picked up,
   it already has its work directory pre-created and having most of the build
   artifacts of someone else. If the job then uses ci-storage GitHub action to
   restore the files from a slot, it will be very quick, because most of the
   files are already there.

The container in this Dockerfile serves only one particular GitHub repository
(controlled by `GH_REPOSITORY` environment variable at boot time). To serve
different repositories, boot different containers.

We also expose a naming convention on extra entrypoint files. When extending
this image, one can put custom files like `/root/entrypoint.*.sh` (to be run as
root) or `/home/user/entrypoint.*.sh` (to be run as user `user`). Those files
will be automatically picked up and executed.

To enter the container, run e.g.:

```
docker compose exec self-hosted-runner bash -l
```

It will automatically change the user and current directory to `/home/user`
(without `-l`, it will run a root shell session).

See also https://github.com/dimikot/ci-storage
