# Publishing CopyCue through npm

The MVP npm package contains the Apple Silicon `CopyCue.app` bundle. Users need Node.js and npm, but they do not need Swift, Xcode, or administrator access.

## Package ownership

The public package uses the `morning-corp` npm account scope:

```text
@morning-corp/copycue
```

## Authenticate without sharing a token

Sign in directly from the publishing Mac:

```bash
npm login
npm whoami
```

Do not put an npm access token in this repository, its `.npmrc`, a shell-history command, or a chat message. For automated releases, configure npm trusted publishing from a supported CI provider instead of storing a long-lived publishing token.

## Test the release artifact

```bash
npm test
npm pack --dry-run
```

The `prepack` hook rebuilds CopyCue, verifies its bundle identifier, version, arm64 architecture, and code signature, and then lets npm create the package.

For a full local end-to-end test before publishing:

```bash
npm pack
npx --yes ./morning-corp-copycue-<version>.tgz install
```

This installs CopyCue in `~/Applications/CopyCue.app` and opens it. Remove the generated `.tgz` afterward if it is no longer needed.

## Publish the MVP

```bash
npm publish --access public
```

If the package is scoped to an organization, confirm that your npm account is an owner or member with permission to publish that package.

After publishing, users install and launch CopyCue with one command:

```bash
npx --yes @morning-corp/copycue@latest install
```

New npm releases are scanned before becoming installable. A temporary 404 after a successful publish is expected while that scan is pending.

## Publish an update

Update the package and app version together, test, and publish:

```bash
npm version patch --no-git-tag-version
npm test
npm publish --access public
```

The npm `version` lifecycle synchronizes `CFBundleShortVersionString` in the application's `Info.plist` automatically.

## MVP limitations

- The current package supports Apple Silicon Macs only.
- The app is ad-hoc signed rather than Developer ID signed and notarized.
- A Mac may require the user to approve the app manually in Privacy & Security.
- The package installs in the user's `~/Applications` directory so it does not need `sudo`.
