# will-get

`will`: installs and updates my apps (every repo with the `will-app` topic) from their GitHub releases.

After formatting the PC, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/WiliamMP/will-get/main/install.ps1 | iex
```

That installs the `will` command and every app. Then:

```
will list
will install will-repo
will install --all
will update
```

To add an app: give its repo the `will-app` topic and publish a release with a `-setup.exe`.
