# Changelog

## 0.2.5

- Updated the konflux-build-cli image to a revision that fixes an internal git fetch error that was
caused by different repository submodule URL configurations per branch, resulting in a "not our ref"
error. See [konflux-build-cli#176](https://github.com/konflux-ci/konflux-build-cli/pull/176) for more
details.

## 0.2.4

- Updated the konflux-build-cli image to a revision that builds on top of [task-runner:2.1.0].
  Notably, this makes the git-lfs package available in the Task.

[task-runner:2.1.0]: https://github.com/konflux-ci/task-runner/blob/main/CHANGELOG.md#210

## 0.2.3

- Added `symlinkCheckIgnorePattern` parameter to exclude symlink paths from the checkout symlink check [konflux-build-cli#132](https://github.com/konflux-ci/konflux-build-cli/pull/132)

## 0.2.2

- Fix SSH setup failing when mounted secrets contain symlinks to directories [konflux-build-cli#165](https://github.com/konflux-ci/konflux-build-cli/pull/165)

## 0.2.1

- `refspec` parameter should now accept multiple refspecs separated by whitespace like in git-clone 0.1 [konflux-build-cli#155](https://github.com/konflux-ci/konflux-build-cli/issues/155)
- Fix handling of whitespaces in gitconfig which should fix most of the issues with basic-auth [konflux-build-cli#159](https://github.com/konflux-ci/konflux-build-cli/pull/159)

## 0.2

- Updated base task to git-clone-oci-ta 0.2.
- Removed `gitInitImage` (deprecated since 0.1), `verbose` (replaced by `logLevel`), and `userHome` (handled by konflux-build-cli) parameters.
- Added `logLevel` parameter.

## 0.1

### Added

- The initial version of the `git-clone-oci-ta-min` task!
