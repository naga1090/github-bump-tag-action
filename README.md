# github-bump-tag-action

A GitHub Action that automatically bumps and pushes a [SemVer](https://semver.org/) git tag on merge. Runs entirely in a self-contained Docker container — no dependency on third-party actions.

## How it works

On each merge (or push), the action:

1. Fetches all existing tags
2. Finds the latest tag matching the configured prefix and SemVer format
3. Reads the commit history since the last tag
4. Decides which part to bump based on commit message tokens
5. Creates and pushes the new tag via the GitHub API

If HEAD is already tagged, it skips without error.

## Usage

### On push to main

```yaml
name: Bump version
on:
  push:
    branches:
      - main

jobs:
  bump:
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          fetch-depth: '0'

      - name: Bump version and push tag
        uses: naga1090/github-bump-tag-action@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
```

### On PR merge (recommended)

```yaml
name: Bump version
on:
  pull_request:
    types:
      - closed
    branches:
      - main

jobs:
  bump:
    if: github.event.pull_request.merged == true
    runs-on: ubuntu-latest
    permissions:
      contents: write
    steps:
      - uses: actions/checkout@v4
        with:
          ref: ${{ github.event.pull_request.merge_commit_sha }}
          fetch-depth: '0'

      - name: Bump version and push tag
        uses: naga1090/github-bump-tag-action@v1
        env:
          GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}
          TAG_PREFIX: v
```

> `fetch-depth: '0'` is required — a shallow clone will miss tags and break version detection.

## Bumping behavior

Include a token in your commit message to control which part is bumped:

| Commit message contains | Result |
|---|---|
| `#major` | `1.0.0` → `2.0.0` |
| `#minor` | `1.0.0` → `1.1.0` |
| `#patch` | `1.0.0` → `1.0.1` |
| `#none` | No tag created |
| _(nothing)_ | Uses `DEFAULT_BUMP` (default: `patch`) |

If multiple tokens are present, the highest-ranking one wins.

## Configuration

All options are set via environment variables.

| Variable | Required | Default | Description |
|---|---|---|---|
| `GITHUB_TOKEN` | Yes | — | Token with `contents: write` permission |
| `DEFAULT_BUMP` | No | `patch` | Bump type when no token is in the commit message. Set to `none` to disable automatic bumping. |
| `DEFAULT_BRANCH` | No | `$GITHUB_BASE_REF` | The base/default branch. Auto-detected on PRs. Override if your default branch is not `main` or `master`. |
| `TAG_PREFIX` | No | _(none)_ | Prefix added to every tag, e.g. `v` produces `v1.2.3`. Only tags matching this prefix are considered. |
| `WITH_V` | No | `false` | Deprecated. Use `TAG_PREFIX=v` instead. |
| `RELEASE_BRANCHES` | No | `master,main` | Comma-separated list of branches (regex accepted) that produce release tags. All other branches produce pre-release tags. |
| `PRERELEASE` | No | `false` | Force pre-release mode regardless of branch. |
| `PRERELEASE_SUFFIX` | No | `beta` | Suffix used for pre-release tags, e.g. `1.2.0-beta.1`. |
| `INITIAL_VERSION` | No | `0.0.0` | Starting version if no tags exist yet. Do not include the prefix here. |
| `TAG_CONTEXT` | No | `repo` | Where to look for the latest tag. `repo` = all tags in repo, `branch` = only tags reachable from HEAD. |
| `BRANCH_HISTORY` | No | `compare` | Commit range to scan for bump tokens. `compare` = commits since last tag, `last` = last commit only, `full` = all commits since branching from default branch. |
| `SOURCE` | No | `.` | Relative path under `$GITHUB_WORKSPACE` to operate in. |
| `CUSTOM_TAG` | No | _(none)_ | Override all semver logic and push this exact tag value. |
| `DRY_RUN` | No | `false` | Calculate and output the next tag without pushing it. |
| `GIT_API_TAGGING` | No | `true` | Use GitHub REST API to push the tag. Set to `false` to use `git push` instead. |
| `FORCE_WITHOUT_CHANGES` | No | `false` | Create a tag even if HEAD is already tagged. |
| `VERBOSE` | No | `false` | Print full git log output. |
| `MAJOR_STRING_TOKEN` | No | `#major` | Commit message token that triggers a major bump. |
| `MINOR_STRING_TOKEN` | No | `#minor` | Commit message token that triggers a minor bump. |
| `PATCH_STRING_TOKEN` | No | `#patch` | Commit message token that triggers a patch bump. |
| `NONE_STRING_TOKEN` | No | `#none` | Commit message token that skips tagging entirely. |
| `TAG_MESSAGE` | No | _(none)_ | If set, creates an annotated tag with this message instead of a lightweight tag. |

## Outputs

| Output | Description |
|---|---|
| `new_tag` | The newly created tag value |
| `old_tag` | The previous tag before bumping |
| `tag` | Same as `new_tag` |
| `part` | Which part was bumped: `major`, `minor`, `patch`, or `pre-*` |

Use outputs in downstream steps:

```yaml
- name: Bump version and push tag
  id: bump
  uses: naga1090/github-bump-tag-action@v1
  env:
    GITHUB_TOKEN: ${{ secrets.GITHUB_TOKEN }}

- name: Print new tag
  run: echo "New tag is ${{ steps.bump.outputs.new_tag }}"
```

## Pre-release behavior

If the action runs on a branch not in `RELEASE_BRANCHES`, it creates a pre-release tag:

- First pre-release: `1.1.0-beta.0`
- Subsequent pre-releases on same base: `1.1.0-beta.1`, `1.1.0-beta.2`, ...
- On merge to a release branch: `1.1.0`

## Testing locally

```bash
export GITHUB_WORKSPACE=$(pwd)
export GITHUB_OUTPUT=/tmp/gh_output
export DRY_RUN=true
export TAG_PREFIX=v
bash entrypoint.sh
```

Run the bats test suite (requires `bats-core`, `bats-support`, `bats-assert`):

```bash
brew install bats-core bats-support bats-assert  # macOS
bats test/test_prefix.bats
```
