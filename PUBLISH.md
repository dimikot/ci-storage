# Publishing a New Version

To publish a new image to Docker Hub:

```
git tag vA.B.C # new version
git push --tags
```

To release a new GitHub Action version to GitHub Marketplace (example for v1
overwrite):

```
git pull --rebase
git tag v1 --force
git push --tags --force 
```

Then open https://github.com/dimikot/ci-storage/releases/edit/v1 and click
**Update Release**.
