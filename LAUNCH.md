# RIFT website and launch checklist

## Launch site

The responsive site is in `website/` with an original right-edge Portal illustration, eight effect descriptions, latest-release download buttons, a privacy page, and installation/support docs.

Deployment workflow: `.github/workflows/pages.yml`.

**One-time GitHub Pages activation required:**

1. Open the repository's **Settings → Pages**.
2. Under **Build and deployment → Source**, select **GitHub Actions**.
3. Wait for **Publish RIFT website** in Actions to succeed. You can manually rerun it if the first attempt ran before Pages was enabled.
4. Before the repository rename, the GitHub Pages URL is expected to be `https://y2kbeatzz-dot.github.io/FlickTunes/`. After the rename to RIFT, it should become `https://y2kbeatzz-dot.github.io/RIFT/` (confirm Pages finishes deploying after the rename).

No custom domain has been configured.

## Rename repository FlickTunes → RIFT

**GitHub's connected API currently supports code editing but does not expose repository renaming. The repository has NOT been renamed automatically.**

Option A — GitHub UI:

1. Open `https://github.com/y2kbeatzz-dot/FlickTunes/settings`.
2. In General find **Repository name**.
3. Enter **RIFT** and click **Rename**.
4. Verify the new URL `https://github.com/y2kbeatzz-dot/RIFT`.

Option B — GitHub CLI on your Mac:

```bash
brew install gh
gh auth login
gh repo rename -R y2kbeatzz-dot/FlickTunes RIFT --yes
```

The existing GitHub repository redirects old repo paths after a rename, but update any saved local Git remotes when convenient:

```bash
git remote set-url origin https://github.com/y2kbeatzz-dot/RIFT.git
```

If the repository was already renamed, don't repeat the rename command.

## Releases and packages

The repository had **16** GitHub releases during launch review: one current RIFT release and 15 older FlickTunes development builds.

The current `.github/workflows/build.yml` publishes the new RIFT IPA/DMG/checksums and then tries to delete only older automated `build-N-attempt-N` releases **plus their attached assets and release tags**. It keeps:

- The newest just-published RIFT development release.
- Any intentionally versioned `v*` release.
- All source code, commit history, branches and pull requests.

Check `https://github.com/y2kbeatzz-dot/RIFT/releases` after rename to confirm cleanup succeeded. Failed cleanup attempts are logged as warnings, not silently treated as successful. Historical GitHub Actions runs are **not** deleted.

## Distribution readiness

The RIFT iPhone IPA is **unsigned** and requires the user's own signing team or a signing tool before iPhone installation. The Mac DMG is ad-hoc signed, **not Apple Developer ID signed or notarized**, and macOS may block its launch until the user approves a verified download. Compiling and publishing the files does not establish end-to-end device test results.

Before public App Store or broadly advertised launch: physically test file/link/music handoff and all effects, select an explicit open-source license if desired (none has been added by this task), and set up Apple Developer ID signing/notarization and iPhone distribution.

## Owner

**Created by Ksyusha (life999)** — https://guns.lol/life999
