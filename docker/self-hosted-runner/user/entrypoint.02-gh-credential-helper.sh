#!/bin/bash
#
# To make "git clone" command work for HTTPS origin URLs like
# https://github.com/... by default, you must understand how Git credential
# helper works in tandem with "gh" CLI tool:
#
# - https://git-scm.com/docs/gitcredentials
# - https://cli.github.com/manual/gh_auth_setup-git
#
# If you look in ~/.gitconfig file, you should see the global Git config
# mentioned in the script below.
#
# It means that every time you run e.g. "git clone" or "git fetch" for a HTTPS
# repo, Git will run "gh" CLI tool asking it to provide the token to access the
# GitHub account. And "gh" CLI tool will just use the token in GH_TOKEN (or
# GITHUB_TOKEN) environment variable which is set by GitHub Actions framework.
#
# I.e. this method allows vanilla git use GitHub token from GH_TOKEN or
# GITHUB_TOKEN which is set there by GitHub Actions framework.
#
set -u -e

cat <<EOT > ~/.gitconfig
[credential "https://github.com"]
helper =
helper = !/usr/bin/gh auth git-credential
EOT
