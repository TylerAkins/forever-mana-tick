# Releases

## Versioned release

VERSION is the addon version source. RELEASE_NOTES.md contains the current release notes; CHANGELOG.md retains release history. Packaged TOCs resolve `@project-version@` to the release version.

Run the runtime and updater tests, build the ZIP, inspect its contents and manifest, and complete the in-game checklist. Approve the version, exact notes, client scope, and destinations before setting the GitHub Actions variable `RELEASE_ENABLED` to `true` and publishing an annotated `v0.1.0` tag. The tag workflow validates the version and publishes the inspected archive with the same notes through the GitHub CLI. Do not move published tags.

The Wednesday updater prepares a pull request. A metadata change does not establish compatibility. Once `RELEASE_ENABLED` is approved and enabled, merging an interface update with the next patch version automatically creates the matching tag and dispatches publication, following the reference repository's behavior. Until then, merging does not publish. Approval to enable this variable must include that continuing automatic release policy.

For automation-created pull requests, select **Approve workflows to run** in GitHub's merge box if prompted, then wait for the required `validate` check. GitHub documents this approval for pull requests created by GITHUB_TOKEN in [Triggering a workflow](https://docs.github.com/en/actions/how-tos/write-workflows/choose-when-workflows-run/trigger-a-workflow). A manually dispatched CI run does not satisfy the pull request's required branch-ruleset check.

## CurseForge setup

Create a WoW addon project named **Forever Mana Tick**, with MIT licensing and the description from README.md. Use `ForeverManaTick` as the installed folder. Add the GitHub source and issue links.

Connect `TylerAkins/forever-mana-tick` in the CurseForge project's source/packaging settings and configure release-tag packaging. Its project-specific webhook must be created by that connection. Do not copy forever-quest-markers' webhook token or project ID. The reference repository uses CurseForge webhook packaging rather than an upload secret in GitHub Actions.

The repository includes `.pkgmeta`, manual Markdown release notes, resolved version packaging, and the original MIT license. Confirm CurseForge supports the Forever game version and select that exact flavor/build. Do not substitute Era or Retail if Forever is unavailable. Check the resulting file, supported version, notes, and moderation status after the first upload.

No CurseForge project, upload token, or webhook is configured by this repository. GitHub publication and CurseForge publication are separate observed states.
