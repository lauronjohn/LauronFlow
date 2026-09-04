# Deploying LauronFlow

Two independent deploys: the **app** (shipped to GitHub Releases) and the **landing
site** (served by Cloudflare). Changing one never requires redeploying the other.

## 1. The app — GitHub Release

The app ships as a prebuilt `LauronFlow.app.zip` attached to a GitHub Release, tagged
with the same version as the app's marketing version.

### 1a. Bump the version

Edit `project.yml`:

```yaml
info:
  properties:
    CFBundleShortVersionString: "1.0.X"   # marketing version (matches the tag)
    CFBundleVersion: "N"                  # build number, +1 each release
```

### 1b. Build & install locally

```bash
cd ~/Documents/GitHub/LauronFlow

xcodegen generate              # regenerate the Xcode project from project.yml
./install.sh                   # build, code-sign, install to /Applications, relaunch
```

`install.sh` needs: `xcodegen`, `uv`, `ffmpeg`, and the `LauronFlow Local Dev`
code-signing certificate (README has one-time setup). Smoke-test dictation before
shipping.

### 1c. Package the release zip

```bash
BUILT="$(ls -d ~/Library/Developer/Xcode/DerivedData/LauronFlow-*/Build/Products/Debug/LauronFlow.app)"
mkdir -p /tmp/release
ditto -c -k --keepParent --norsrc "$BUILT" /tmp/release/LauronFlow.app.zip
```

`--norsrc` is load-bearing: it omits AppleDouble (`._`) files that otherwise break
`codesign --verify --deep`. Optional sanity check:

```bash
cd /tmp/release && unzip -q LauronFlow.app.zip -d /tmp/lf_verify && \
  codesign --verify --deep --strict /tmp/lf_verify/LauronFlow.app && echo OK
```

### 1d. Commit, tag, push, release

```bash
cd ~/Documents/GitHub/LauronFlow

git add -A
git commit -m "<summary>; v1.0.X"
git tag v1.0.X
git push origin main
git push origin v1.0.X

gh release create v1.0.X \
  --title "LauronFlow v1.0.X" \
  --notes-file /tmp/release/notes.md \
  /tmp/release/LauronFlow.app.zip
```

Write the release notes to `/tmp/release/notes.md` first (see CHANGELOG.md for the
source material).

### 1e. Sidecar repo (only when `sidecar/` changed)

`sidecar/` is its own repo. If the Python code changed, commit/tag/release it too:

```bash
cd ~/Documents/GitHub/LauronFlow/sidecar
# bump version in pyproject.toml
git add -A && git commit -m "..."
git tag v0.2.X && git push origin main && git push origin v0.2.X
gh release create v0.2.X --title "lauronflow-sidecar v0.2.X" --notes "..."
```

Update CHANGELOG.md with the new entry, and remember to bump the version in `project.yml`
in the *main* repo even when only the sidecar changed (so users can see they're current).

## 2. The landing site — Cloudflare

The site is a static folder (`landing/index.html` + `logo.png`), deployed to Cloudflare
Workers/Pages. The domain `lauronflow.app` is already on Cloudflare, so DNS is never
touched again.

```bash
cd ~/Documents/GitHub/LauronFlow/landing

cp index.html logo.png dist/     # refresh the built files
wrangler deploy                  # deploys to Cloudflare in ~5s
```

`wrangler.jsonc` serves `./dist`, and `.gitignore` excludes `.wrangler`, `dist`, `.env`,
and other build/secret artifacts.

The source of truth for the site is `landing/index.html`. `landing/dist/` is a build
artifact and is gitignored — always `cp` into it before deploying.

## Gotchas that have bitten us before

- **Zip without `--norsrc`** → code signature invalid on other machines ("sealed
  resource is missing or invalid"). Always use `ditto -c -k --keepParent --norsrc`.
- **Forgot `xcodegen generate`** after editing `project.yml` → version number doesn't
  actually change in the built app.
- **Forgot `./install.sh`** → local `/Applications` copy doesn't match the release.
- **Deployed from the wrong folder** → Cloudflare served junk (`.wrangler`,
  `wrangler.jsonc`, dotfiles). Only `landing/dist/` should contain `index.html` +
  `logo.png`.
