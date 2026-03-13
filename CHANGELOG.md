# Changelog

## [1.2.0](https://github.com/mmihalev/magic-mouse-battery-monitor/compare/v1.1.0...v1.2.0) (2026-03-13)


### Features

* default auto update check to disabled and clarify update notification behavior in documentation. ([0d5430f](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/0d5430ff0f949d8201787edbae8686761aa345ef))
* Implement auto-update checks and enhance the installation and update flow with version comparison and setting persistence. ([6ce0d68](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/6ce0d68f2a7d7bd6eab5b6fabd8a16002a46f2e4))


### Bug Fixes

* update checksum ([4fb7e4b](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/4fb7e4b4f0d6da092f293de7c8cbb30f3b1e81bc))


### Code Refactoring

* change checksum workflow to validate `install.sh` checksum and remove auto-commit functionality. ([7b33bec](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/7b33bec2cb0ab9077c32e9d49c6faaaa30fc3bbc))
* remove auto-fix for install.sh checksum and add conditional validation for pull requests. ([e2ef02c](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/e2ef02c09f44f83d14ab5a8cd08c8c1be02303b8))


### Documentation

* Clarify battery threshold notification behavior in README. ([3132493](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/3132493aed53098c264e5243b71a89e9999abe8a))

## [1.1.0](https://github.com/mmihalev/magic-mouse-battery-monitor/compare/v1.0.0...v1.1.0) (2026-03-13)


### Features

* add release-please configuration and manifest files, updating the CI workflow to use them. ([2da1b28](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/2da1b28ca77ccd1715cbf3442f2d96124ac121cb))
* configure release-please action with token, config-file, and manifest-file parameters ([6377d4c](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/6377d4c3f242bc7fa415485581c77fca52d1596e))


### Bug Fixes

* rename release-please manifest file ([20c911f](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/20c911fd15c42fd62e38d8e3b9a67ff01cd50fe5))
* run required checks on release-please pull requests ([f173f69](https://github.com/mmihalev/magic-mouse-battery-monitor/commit/f173f691baba48cad24766552c2532b6499e30b2))
