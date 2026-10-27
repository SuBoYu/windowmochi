# GitHub repository setup

The project is hosted at [SuBoYu/windowmochi](https://github.com/SuBoYu/windowmochi).

## Repository settings

| Field | Value |
| --- | --- |
| Name | `windowmochi` |
| Description | `A cute macOS menu bar app that remembers your window layouts and restores them across multiple displays, with global shortcuts and multilingual support.` |
| Visibility | Private for personal development, or Public when ready to share |
| Suggested topics | `macos`, `swift`, `window-manager`, `multi-monitor`, `productivity`, `mochi` |

The repository already includes a README and `.gitignore`. Select a license before distributing the project under an open-source license.

## Clone an existing repository

```sh
git clone https://github.com/SuBoYu/windowmochi.git
cd windowmochi
```

After editing files, review and commit the changes, then push them to the appropriate branch. Do not repeat the initialization steps below in an existing checkout.

## First upload to a new repository

These steps are for a new project that is not yet tracked by Git. On GitHub, create an empty repository without adding a README, `.gitignore`, or license to avoid conflicts with local files.

In the project directory, replace `YOUR_USERNAME` with your GitHub account:

```sh
git init -b main
git add .gitignore Package.swift README.md Sources scripts tests docs assets
git diff --cached --stat
git commit -m "Initial WindowMochi app with localization and global shortcuts"
git remote add origin https://github.com/YOUR_USERNAME/windowmochi.git
git push -u origin main
```

Authenticate before pushing using your configured SSH or HTTPS credentials, or GitHub CLI with `gh auth login` and `gh auth setup-git`.

## Included files

- `Sources/WindowMochi/`: Swift source and four language resource files.
- `scripts/build.sh` and `scripts/build-icon.sh`: compilation, mascot icon packaging, and local signing.
- `assets/branding/`: mascot PNG and generation prompt.
- `tests/`: translation coverage and format-argument checks.
- `README.md`, `docs/`, `Package.swift`, and `.gitignore`.

Build caches, packaged apps, and `.DS_Store` files are excluded. User layouts and window titles remain in Application Support, outside the repository.

Installable app bundles can be shared separately through GitHub Releases. Current builds target Apple Silicon, use ad-hoc signing, and are not notarized by Apple.

## References

- [Creating a new repository](https://docs.github.com/en/repositories/creating-and-managing-repositories/creating-a-new-repository)
- [Adding locally hosted code to GitHub](https://docs.github.com/en/migrations/importing-source-code/using-the-command-line-to-import-source-code/adding-locally-hosted-code-to-github)
