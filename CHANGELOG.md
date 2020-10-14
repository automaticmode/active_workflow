# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).


## [current]
### Changed
- Updated `mini_racer` and `libv8` - current combination started failing
  to install on MacOS.
- Updated `puma` - MacOS related [issue](https://github.com/puma/puma/issues/2304).
- Renamed `headers_to_save` to `headers_to_include` in HTTP Status Agent.
- Replace `working` with `issues` and add desctiptions.


## [0.9.10]
### Fixed
- Don't use `foreman` to manage multiple processes when running with
  `SINGLE_DYNO=1`. Single-dyno mode was demoted to being used purely for trying
  out ActiveWorkflow on Heroku (including Free plan). Functionality
  previously provided by foreman reimplemented as a simple shell script using
  job control functionality of bash. Fixes #9.

### Changed
- Both docker-compose and deployment to heroku (via single button deployment)
  switched to using official docker images of ActiveWorkflow by default instead
  of building images from source - mostly to save time spent building docker
  image every single time. Of course, you can still build your own images from
  source. The *latest versioned* image (eg.
  automaticmode/active_workflow:0.9.10) is used.


## [0.9.9.2] - 2020-09-09
### Fixed
- Correct broken docker-compose syntax.
- Properly initialise database when starting web container.


## [0.9.9.1] - 2020-08-31
### Changed
- Start multiple containers (separate ones for web, scheduler and worker) when
  using default docker-compose configuration.

### Fixed
- Update kramdown (CVE-2020-14001).


## [0.9.9] - 2020-07-19
### Fixed
- Update puma (CVE-2020-11076 and CVE-2020-11077).
- Update rails (CVE-2020-8165, CVE-2020-8164, CVE-2020-8162 and CVE-2020-8185).
- Update kaminari (CVE-2020-11082).
- Update websocket-extensions (CVE-2020-7663).
- Update rack (CVE-2020-8184).

### Removed
- Wunderlist agent removed (service has shut down).

### Changed
- Remove SchedulerAgent (to be implemented as a core functionality).
- Refactor agent runner and scheduler.
- `SEED_DATABASE` and `DO_NOT_CREATE_DATABASE` environment flags where inverted and replaced with 
  `DO_NOT_SEED` and `CREATE_DATABASE` correspondingly to represent default execution path.
- You can now use Heroku single button deployment for both demonstration
  purposes running on free tier and production with scalable dyno formations.
  This is controlled with a single environment variable `SINGLE_DYNO`.


## [0.9.8] - 2020-05-11
### Fixed
- Update puma (CVE-2020-5249).
- Update rails, grape (CVE-2020-5267).

### Changed
- Upgrade to Rails 6.


## [0.9.7] - 2020-02-28
### Changed
- The semantics of message delivery got improved: agents now process a single
  message at a time, thus matching transactional boundaries.
- BREAKING: CSV Agent in 'serialize' mode handles only a single message at a
  time and can't aggregate multiple 'row' messages into a single CSV. Old
  behavior wasn't exactly deterministic, a suggested way would be to use
  `Digest Agent` to aggregate messages and then serialize them with
  `CSV Agent`.

### Fixed
- Update nokogiri (CVE-2020-7595).
- Update rack (CVE-2019-16782).
- Update puma (CVE-2019-16770).
- Fix regression for 'Delete Messages' button.


## [0.9.6] - 2019-12-09
### Added
- Support for remote agents. Custom agents can now be written in any
  programming language and use any technology stack.

### Changed
- All agents now use common `working` logic.

### Fixed
- Update loofah (CVE-2019-15587).
- Don't use vendor/cache when building docker image.


## [0.9.5.1] - 2019-10-31
### Added
- Add live updates to the table and diagram of agents.

### Fixed
- (Fix #1 ) ActiveWorkflow can now be started with `docker-compose up`
  without pre-built image.


## [0.9.5] - 2019-10-16
### Added
- Basic REST API to query state of the system.

### Removed
- Google Calendar Publishing Agent. This removal is temporary (conflicting
  dependencies), the agent will return soon. If you are using this agent please
  skip this version.


## [0.9.4] - 2019-10-09
### Added
- Support writing custom agent in ruby using custom agent API
  (decoupled from ActiveRecord).
- Use codecov for tracking code coverage.

### Removed
- Legacy system to write custom agents.

### Changed
- Switch from firefox to chromium to run feature tests.

### Fixed
- Documentation tweaks.
- Update devise (CVE-2019-16109).
- Update rubyzip (CVE-2019-16892).


## [0.9.3]
### Fixed
- README tweaks.
- Removed broken docker image dependency.
- Update nokogiri (CVE-2019-5477).


## [0.9.2] - 2019-08-07
### Fixed
- Docker compose doesn't restart container anymore.
- Updated dependencies.


## [0.9.1] - 2019-07-02
### Added
- Simple change log file.

### Changed
- Use ruby:2.6.3-slim docker image instead of ubuntu:16.04.
- Don't use supervisord in a container.

### Fixed
- Fixed deprecated devise error messages.
- Updated dependencies.


## [0.9.0] - 2019-03-29
### Added
- Initial public release

[current]: https://github.com/automaticmode/active_workflow/compare/v0.9.10...HEAD
[0.9.10]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.10
[0.9.9.2]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.9.2
[0.9.9.1]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.9.1
[0.9.9]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.9
[0.9.8]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.8
[0.9.7]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.7
[0.9.6]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.6
[0.9.5.1]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.5.1
[0.9.5]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.5
[0.9.4]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.4
[0.9.3]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.3
[0.9.2]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.2
[0.9.1]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.1
[0.9.0]: https://github.com/automaticmode/active_workflow/releases/tag/v0.9.0
