# release-it

A handy pair of scripts for managing your CHANGELOG and initiating a versioned release.
Unreleased change entries are stored in separate files to avoid the merge conflicts you get when multiple people/branches modify the CHANGELOG.

To get the latest version run this from the root of your git repository:

```bash
wget -q --backups https://github.com/at055612/release-it/releases/latest/download/{log_change,tag_release}.sh && echo "Downloaded $(grep -o "Version: .*" tag_release.sh)"
```

## `log_change.sh`

This script creates unique change entry files for unreleased changes.

Features:

* Creates change entries linked to GitHub issues.
  * Validates the issue number.
  * Writes the issue title to the change entry file.
  * Supports issues in different repositories.
  * Supports deriving the issue number from branch name (e.g. branch `gh-nnn-` or `nnn-`).
* Creates simple change entries not linked to GitHub issues.
* ISO 8601 date filenames for implicit ordering.


## `tag_release.sh`

This script initiates a versioned release by updating the CHANGELOG and creating an annotated git tag.

Features:

* Adds the content of the unreleased change entry files (created by `log_change.sh`) to the CHANGELOG.
* Guesses the next version based on the previous release.
* Adds a new version heading to CHANGELOG.
* Adds/updates the version compare links in the CHANGELOG.

## Credits

Credit for the idea of storing unreleased change log entries in separate files goes to:

https://about.gitlab.com/blog/2018/07/03/solving-gitlabs-changelog-conflict-crisis/

