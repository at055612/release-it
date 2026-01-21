# Change Log
All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](http://keepachangelog.com/) 
and this project adheres to [Semantic Versioning](http://semver.org/).


## [Unreleased]

~~~
DO NOT ADD CHANGES HERE - ADD THEM USING log_change.sh
~~~


## [v0.5.2] - 2026-01-21

* Bug : Fix git branch regex to support branches like 'xxx/1234'.


## [v0.5.1] - 2026-01-16

* Build : Fix CI build.

* Bug : Fix bug in category checking.


## [v0.5.0] - 2026-01-16

* Bug : Fix tag_release so it checks for presence of branch on remote.

* Feature : Add change categories to change entries (Bug/Feature/Dependency/Refactor).

* Feature : Add FZF integration for users that have it installed.


## [v0.4.1] - 2023-01-16

* Fix bug when there are no change files.


## [v0.4.0] - 2022-09-27

* Add wrapping to 80 chars to `list` output.


## [v0.3.0] - 2021-11-04

* Add looping to file validation.

* Add validation of tense.


## [v0.2.3] - 2021-11-03

* Improve change text validation.


## [v0.2.2] - 2021-11-02

* Change log_change.sh to use tag_release_config.env git namespace/repo values

* Add issue link to change entry file

* Change `list` entries to not be yellow.


## [v0.2.1] - 2021-10-21

* Fix missing issue title when using auto mode


## [v0.2.0] - 2021-10-21

* Fix change entry file validation

* Add choice to open existing or create new

* Add support for change entries in the changelog

* Add more tidying of the whitespace in the changelog


## [v0.1.8] - 2021-10-20

* Change change file comments to fenced block


## [v0.1.7] - 2021-10-20

* Add check for github api http status


## [v0.1.6] - 2021-10-20

* Add build data/version to log_change.sh


## [v0.1.5] - 2021-10-20

* Add setting of build version and date


## [v0.1.4] - 2021-10-20

* Add missing constant to ci_build.sh


## [v0.1.3] - 2021-10-20

* Add more logging to ci_build.sh


## [v0.1.2] - 2021-10-20

* Add github actions workflow


## [v0.1.1] - 2021-10-20

* Fix commit message logic


## [v0.1.0] - 2021-10-20

* Initial release


[Unreleased]: https://github.com/at055612/release-it/compare/v0.5.2...master
[v0.5.2]: https://github.com/at055612/release-it/compare/v0.5.1...v0.5.2
[v0.5.1]: https://github.com/at055612/release-it/compare/v0.5.0...v0.5.1
[v0.5.0]: https://github.com/at055612/release-it/compare/v0.4.1...v0.5.0
[v0.4.1]: https://github.com/at055612/release-it/compare/v0.4.0...v0.4.1
[v0.4.0]: https://github.com/at055612/release-it/compare/v0.3.0...v0.4.0
[v0.3.0]: https://github.com/at055612/release-it/compare/v0.2.3...v0.3.0
[v0.2.3]: https://github.com/at055612/release-it/compare/v0.2.2...v0.2.3
[v0.2.2]: https://github.com/at055612/release-it/compare/v0.2.1...v0.2.2
[v0.2.1]: https://github.com/at055612/release-it/compare/v0.2.0...v0.2.1
[v0.2.0]: https://github.com/at055612/release-it/compare/v0.1.8...v0.2.0
[v0.1.8]: https://github.com/at055612/release-it/compare/v0.1.7...v0.1.8
[v0.1.7]: https://github.com/at055612/release-it/compare/v0.1.6...v0.1.7
[v0.1.6]: https://github.com/at055612/release-it/compare/v0.1.5...v0.1.6
[v0.1.5]: https://github.com/at055612/release-it/compare/v0.1.4...v0.1.5
[v0.1.4]: https://github.com/at055612/release-it/compare/v0.1.3...v0.1.4
[v0.1.3]: https://github.com/at055612/release-it/compare/v0.1.2...v0.1.3
[v0.1.2]: https://github.com/at055612/release-it/compare/v0.1.1...v0.1.2
[v0.1.1]: https://github.com/at055612/release-it/compare/v0.1.0...v0.1.1
[v0.1.0]: https://github.com/at055612/release-it/compare/v0.1.0...v0.1.0
