# will-get

`will`: installs and updates my apps (every repo with the `will-app` topic) from their GitHub releases.

After formatting the PC, in PowerShell:

```powershell
irm https://raw.githubusercontent.com/WiliamMP/will-get/main/install.ps1 | iex
```

That installs only the `will` command. Then:

```
will list
will install will-repo
will install --all
will update            # updates will itself too
will uninstall will-repo
```

To add an app: give its repo the `will-app` topic and publish a release with a `-setup.exe`.
