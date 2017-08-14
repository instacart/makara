# Change Log
All notable changes to this project will be documented in this file.

## v0.3.9 - 2017-08-14
[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.8...v0.3.9) 

Changed
- Add postgis support [#118](https://github.com/taskrabbit/makara/pull/118) Kevin Bacha

## v0.3.8 - 2017-07-11

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.7...v0.3.8) 

Changed
- Rails 5.1 compatibility [#150](https://github.com/taskrabbit/makara/pull/150) Jeremy Daer
- Minimize redundant context cache requests [#157](https://github.com/taskrabbit/makara/issues/157) Greg Patrick
- thread-local cache for previous context stickiness [#158](https://github.com/taskrabbit/makara/issues/158)  Jeremy Daer
- Configurable cookie options [#159](https://github.com/taskrabbit/makara/pull/159) Jeremy Daer
- Test against Rails 5.x and Ruby 2.x [#160](https://github.com/taskrabbit/makara/pull/160) Jeremy Daer

## v0.3.7 - 2016-09-22

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.6...v0.3.7)

Changed

- Fix the hierarchy of the config file [#116](https://github.com/taskrabbit/makara/pull/116) Kevin Bacha
- "Disable blacklist" parameter [#134](https://github.com/taskrabbit/makara/pull/134) Alex Tonkonozhenko
- Fixes bug in `without_sticking` [#96](https://github.com/taskrabbit/makara/pull/96) Brian Leonard
- Always stick inside transactions [#96](https://github.com/taskrabbit/makara/pull/96) Brian Leonard
- Rails 5 support [#122](https://github.com/taskrabbit/makara/pull/122) Jonny McAllister

## v0.3.6 - 2016-04-21

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.5...v0.3.6)

Changed

- Allow different strategies such as `priority` and `round_robin` for pools [#105](https://github.com/taskrabbit/makara/pull/105) Brian Leonard


## v0.3.5 - 2016-01-08

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.4.rc1...v0.3.5)

Changed

- Raise `Makara::Errors::AllConnectionsBlacklisted` on timeout. [#104](https://github.com/taskrabbit/makara/pull/104) Brian Leonard

## v0.3.4.rc1 - 2016-01-06

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.3...v0.3.4.rc1)

Added

- Add `url` to database connections configurations. [#93](https://github.com/taskrabbit/makara/pull/93) Benjamin Fleischer

Changed

- Improve Postgresql compatibility and failover support, also fix [#78](https://github.com/taskrabbit/makara/issues/78), [#79](https://github.com/taskrabbit/makara/issues/79). [#87](https://github.com/taskrabbit/makara/pull/87) Vlad
- Update README: Specify newrelic_rpm gem versions that will have the performance issue. [#95](https://github.com/taskrabbit/makara/pull/95) Benjamin Fleischer

## v0.3.3 - 2015-05-20

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.2...v0.3.3)

Changed

- A context is local to the curent thread of execution. This will allow you to stick to master safely in a single thread in systems such as sidekiq, for instance. Fix [#83](https://github.com/taskrabbit/makara/issues/83). [#84](https://github.com/taskrabbit/makara/pull/84) Matt Camuto

## v0.3.2 - 2015-05-16

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.1...v0.3.2)

Fixed

- Fix a `ArgumentError: not delegated` error for rails 3. [#82](https://github.com/taskrabbit/makara/pull/82) Eric Saxby

Changed

- Switch log format from `:info` to `:error`. Mike Nelson

## v0.3.1 - 2015-05-08

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.0...v0.3.1)

Changed

- Globally move to multiline matchers. Mike Nelson

Changed

## v0.3.0 - 2015-04-27

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.0.rc3...v0.3.0)

Changed

- Reduce logging noise by using [the same rules as ActiveRecord uses](https://github.com/rails/rails/blob/b06f64c3480cd389d14618540d62da4978918af0/activerecord/lib/active_record/log_subscriber.rb#L33). [#76](https://github.com/taskrabbit/makara/pull/76) Andrew Kane

Fixed

- Fix an issue for postgres that would route all queries to master. [#72](https://github.com/taskrabbit/makara/pull/72) Kali Donovan
- Fix an edge case which would cause SET operations to send to all connections([#70](https://github.com/taskrabbit/makara/issues/70)). [#80](https://github.com/taskrabbit/makara/pull/80) Michael Amor Righi
- Fix performance regression with certain verions of [newrelic/rpm](https://github.com/newrelic/rpm)([#59](https://github.com/taskrabbit/makara/issues/59)). [#75](https://github.com/taskrabbit/makara/pull/75) Mike Nelson

## 0.3.0.rc3 - 2014-09-02[YANKED]

[Full Changelog](https://github.com/taskrabbit/makara/compare/v0.3.0.rc2...v0.3.0.rc3)

Added
- Allow bypassing of stickiness

## 0.3.0.rc2 - 2014-08-05
Added
- Add postgres specific tests.

Changed
- Change using methods for matchers to be able to monkey patch them.
- Follow AR naming conventions for adapter naming.

## 0.3.0.rc1 - 2014-08-05
Removed
- Remove initial connection logic. If a connection can't be made on startup, an error will be thrown rather than the node getting blacklisted.


## 0.2.2 - 2014-04-03
Added
- Add logging of makara operations via the Makara::Logger.

Changed
- Begin tracing the series of errors associated with blacklisting rather than just the last. This becomes apparent in error messages.
- Fix Rails.cache usage when full environment is not loaded.
