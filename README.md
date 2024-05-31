![CI run](https://github.com/dimikot/ci-storage/actions/workflows/ci.yml/badge.svg?branch=main)

# CI Storage

This repository is a combination of several tools which work in unison:

- [Action: ci-storage](#action-ci-storage). A GitHub action which uses ci-storage command-line tool.
- [Command-line tool: ci-storage](https://github.com/dimikot/ci-storage/blob/main/ci-storage). The tool itself. It can be used stand-alone too.
- [Docker image: ci-storage](https://github.com/dimikot/ci-storage/tree/main/docker/ci-storage). Allows to launch ci-storage part of self-hosted runners infra.
- [Docker image: ci-scaler](https://github.com/dimikot/ci-storage/tree/main/docker/ci-scaler). Scales runners based on GitHub's webhook signal using various heuristics.
- [Docker image: ci-runner](https://github.com/dimikot/ci-storage/tree/main/docker/ci-runner). Allows to launch self-hosted runners themselves.

## Action: ci-storage

This [action](https://github.com/dimikot/ci-storage/blob/main/action.yml)
quickly (only when run on your own self-hosted runners infra) stores the content
of the work directory in the storage with the provided slot id on a remote host,
or loads the content from the storage to that directory. The tool makes some
smart differential optimizations along the way to operate as fast as possible
(typically, 4 seconds for a 1.5G directory with 200K files in it on Linux EXT4).

Under the hood, the tool uses rsync. When storing to the remote storage, it uses
rsync's "--link-dest" mode pointing to the most recently created slot, to reuse
as many existing files in the storage as possible (hoping that almost all files
to be stored in the current slot are the same as the files in the recent slot,
which is often times true for e.g. node_modules directories). If a slot with the
same id already exists, it is overwritten in a transaction-safe fashion.

When loading the files from a remote storage slot to a local directory, implies
that the local directory already contains almost all files equal to the remote
ones, so rsync can run efficiently.

> [!NOTE]
>
> This tool makes sense only when using it with [Self-Hosted
> Runners](https://docs.github.com/en/actions/hosting-your-own-runners/managing-self-hosted-runners/about-self-hosted-runners).
> The main idea is to reuse the previous build artifacts in work directories,
> which is not possible with default GitHub-Hosted Runners (GitHub always boots
> the virtual machines with empty work directories).

### Usage

<!-- start usage -->
```yaml
- uses: dimikot/ci-storage@v1
  with:
    # What to do (store or load).
    # Required.
    action: ''

    # Storage host in the format [user@]host[:port]; it must allow password-free
    # SSH key based access.
    # Default: the content of ~/ci-storage-host file.
    storage-host: ''

    # Storage directory on the storage host.
    # Default: /mnt/{owner}/{repo} in the storage host's user home.
    storage-dir: ''

    # Remove slots created earlier than this many seconds ago.
    # Default: 14400 (4 hours)
    storage-max-age-sec: ''

    # Id of the slot to store to or load from; use "*" to load a smart-random
    # slot (e.g. most recent or best in terms of layer compatibility) and skip
    # if it does not exist.
    # Default: $GITHUB_RUN_ID
    slot-id: ''

    # Local directory path to store from or load to.
    # Default: "." (the current work directory)
    local-dir: ''

    # Newline separated exclude pattern(s) for rsync.
    # Default: empty
    exclude: ''

    # If set, the final directory on the storage host will be
    # {storage-dir}/{owner}/{repo}.{layer-name}, plus deletion will be turned
    # off on load.
    # Default: empty
    layer-name: ''

    # Newline-separated include pattern(s) for rsync. If set, only the files
    # matching the patterns will be transferred. Implies setting layer-name.
    # Default: empty
    layer-include: ''

    # If set, prints the list of transferred files.
    # Default: false
    verbose: ''
```
<!-- end usage -->

### Example: Build, then Store Work Directory in the Storage

```yaml
jobs:
  build:
    name: Build
    runs-on: [self-hosted]
    steps:
      - name: Checkout
        uses: actions/checkout@v4
      - name: Build
        run: npm i && npm run build
      - name: Store build artifacts, work directory and .git directory
        uses: dimikot/ci-storage@v1
        with:
          action: store
          storage-host: my-hostname.com
  test:
    # ...
  lint:
    # ...
```

### Example: Load Work Directory from the Storage and Run Tests

The benefit in speed can only be achieved if you use self-hosted Action Runners.
In this case, the content of work directory will be reused across the jobs runs,
and ci-storage action will be very quick in loading the files and build
artifacts (it will skip most of unchanged files).

```yaml
jobs:
  build:
    # ...
  test:
    name: Test
    needs: build
    runs-on: [self-hosted]
    steps:
      - name: Load build artifacts, work directory and .git directory
        uses: dimikot/ci-storage@v1
        with:
          action: load
          storage-host: my-hostname.com
      - name: Run tests
        run: npm run test
  lint:
    # ...
```


## Command-line tool: ci-storage

The command-line tool allows to run ci-storage manually.

- [See source code and description](https://github.com/dimikot/ci-storage/blob/main/ci-storage)


## Docker image: ci-storage

A part of self-hosted runners infra representing the storage for ci-storage tool.

- [See README](https://github.com/dimikot/ci-storage/tree/main/docker/ci-storage)
- [See Docker image: dimikot/ci-storage](https://github.com/dimikot/ci-storage/pkgs/container/ci-storage)


## Docker image: ci-scaler

A part of self-hosted runners infra which dynamically launches more self-hosted
runner spot instances when needed, recycles idle resources etc.

- [See README](https://github.com/dimikot/ci-storage/tree/main/docker/ci-scaler)
- [See Docker image: dimikot/ci-scaler](https://github.com/dimikot/ci-storage/pkgs/container/ci-scaler)


## Docker image: ci-runner

A part of self-hosted runners infra representing GitHub Actions runner.

- [See README](https://github.com/dimikot/ci-storage/tree/main/docker/ci-runner)
- [See Docker image: dimikot/ci-runner](https://github.com/dimikot/ci-storage/pkgs/container/ci-runner)


# License

The project and documentation are released under the [MIT License](LICENSE).
