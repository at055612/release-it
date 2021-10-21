# release-it

A handy pair of scripts for managing your change log and initiating a versioned release.


## What problems does it solve?

The aims of these two scripts are to:

* Make the release process as painless as possible and remove all the mandrolic elements.
* Stop un-released entries in the change log from causing merge conflicts in feature pull requests.
* Help maintain a consistent look to the change log.


### Single command release

Our process for releasing [Stroom](https://github.com/gchq/stroom) is largely driven off an annotated git tag.
We update the change log to reflect the version number we are about to release.
We then tag git with an annotated tag that contains the release version as its title and the changes in the release as the content.
Github actions will then kick in and perform a build for this release version and if successful will publish artefacts to Sonatype, Dockerhub and GitHub releases.

The above used to involve multiple manual edits to the change log and various git commands to initiate the release.
Now you just run `./tag_release.sh`, respond to a couple of prompts and you are done.


### Preventing merge conflicts

Our bug fixes and new features are generally all done on feature branches.
Each one will update the top of the change log file to record what has changed in the application.
These change log entries almost always result in merge conflicts (on the change log file) in the pull requests which slows down the process of merging in fixes/changes.

To avoid these conflicts, un-released change log entries are now stored in separate uniquely named files.
With each change entry in its own file there will be no conflicts caused by the change entries.
If you use the convention of including the issue number in your feature branch, you can now just do something like this:

```bash
./log_change.sh auto "Add vim key bindings to editor"
```


## Getting started

To get the latest version run this from the root of your git repository:

```bash
for f in log_change.sh tag_release.sh; do; curl -Lso $f https://github.com/at055612/release-it/releases/latest/download/$f && chmod u+x $f && echo "Downloaded $f $(grep -o "Version: .*" $f)"; done
```

## The scripts


### `log_change.sh`

This script creates unique change entry files for unreleased changes.

Features:

* Creates change entries linked to GitHub issues.
  * Validates the issue number.
  * Writes the issue title to the change entry file.
  * Supports issues in different repositories.
  * Can derive the issue number from branch name (e.g. branch `gh-nnn-` or `nnn-`).
  * Multiple change files per issue.
* Creates simple change entries not linked to GitHub issues.
* ISO 8601 dated filenames for implicit ordering and uniqueness.

Examples:

```bash
# Log a change for the issue number in your current branch (e.g. branch: gh-1234-fix-dead-locks)
./log_change auto "Fix database dead locks during purge job"

# Log a change for the issue number in your current branch (e.g. branch: gh-1234-fix-dead-locks)
# Your default editor will open the created skeleton change file
./log_change auto

# Log a change with no associated issue
./log_change 0 "Fix typo on about screen"

# Log a change for issue #1234
./log_change 1234 "Fix database dead locks during purge job"

# Log a change for issue #1234
# Your default editor will open the created skeleton change file
./log_change 1234

# Log a change for an issue in a different repository
./log_change gchq/stroom#2424 "Fix database dead locks during purge job"

# Log a change for an issue in a different repository
# Your default editor will open the created skeleton change file
./log_change gchq/stroom#2424

# List all unreleased changes
./log_change list

```


### `tag_release.sh`

This script initiates a versioned release by updating the CHANGELOG and creating an annotated git tag.

Features:

* Creates its own configuration file on first use (if not found).
* Creates an empty change log file on first use (if not found).
* Adds the content of the unreleased change entry files (created by `log_change.sh`) to the CHANGELOG.
* Guesses the next version based on the previous release.
* Adds a new version heading to change log.
* Adds/updates the version compare links in the CHANGELOG.
* Commits and pushes the change log changes.
* Creates an annotated git tag using the release version number and change entries.


## Dependencies

Requires: 

 * `bash` v4 or greater.
 * GNU `grep`.
 * GNU `sed`.

If you have `jq` installed it will use that, else it will fall back on grep.


## Credits

Credit for the idea of storing unreleased change log entries in separate files goes to:

https://about.gitlab.com/blog/2018/07/03/solving-gitlabs-changelog-conflict-crisis/

This repo is my take on their idea.
