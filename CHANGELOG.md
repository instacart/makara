# Change Log
All notable changes to this project will be documented in this file.

## v0.5.0 - 2021-01-08
[Full Changelog](https://github.com/instacart/makara/compare/v0.4.1...v0.4.2)
- Replace deprecated URI.unescape with CGI.unescape [#252](https://github.com/instacart/makara/pull/252) Kevin Robatel
- Override equality operator for ActiveRecord connection wrapper [#269](https://github.com/instacart/makara/pull/269) Praveen Burgu
- Handle blacklisted connections in master pool while in transaction [#267](https://github.com/instacart/makara/pull/267) Praveen Burgu
- Handle ActiveRecord connection pools correctly [#267](https://github.com/instacart/makara/pull/267) Praveen Burgu
- Add preliminary support for sharded databases [#267](https://github.com/instacart/makara/pull/267) Praveen Burgu
- Fix ActiveRecord connection pool exhaustion [#268](https://github.com/instacart/makara/pull/268) Praveen Burgu
- Drop support for Ruby 2.0, 2.1 and 2.2 [#267](https://github.com/instacart/makara/pull/267) Praveen Burgu
- Drop support ActiveRecord 3.x and 4.x [#267](https://github.com/instacart/makara/pull/267) Praveen Burgu
- Set up automatic publishing to Github and Rubygems [#275](https://github.com/instacart/makara/pull/275) Matt Larraz


## v0.4.1 - 2019-03-25
[Full Changelog](https://github.com/instacart/makara/compare/v0.4.0...v0.4.1)

- Fix crash by requiring makara in the adapter [#54](https://github.com/instacart/makara/pull/54) Eric Saxby
- Add connection logging in non-Rails enviroments [#223](https://github.com/instacart/makara/pull/223) Andrew Kane

## v0.4.0 - 2018-04-01
[Full Changelog](https://github.com/instacart/makara/compare/v0.3.10...v0.4.0)

This release is a major change to how we remember state between requests. A redis store is no longer needed. Everything is in the cookies.
 - Implement stickiness for the duration of `master_ttl` via cookies [#194](https://github.com/instacart/makara/pull/194) Rosa Gutierrez


## v0.3.10 - 2018-03-20
[Full Changelog](https://github.com/instacart/makara/compare/v0.3.9...v0.3.10)

Fixed
- Send nextval queries to master and show queries to replicas for Postgres [#173](https://github.com/instacart/makara/pull/173) Andrew Kane
- Fixes can't add a new key into hash during iteration error [#174](https://github.com/instacart/makara/pull/174) Andrew Kane
- Fix: an application freezes when a slave is down [#180](https://github.com/instacart/makara/pull/180) Alexey P
- Allow SELECTs that use common table expressions to go to replicas [#184](https://github.com/instacart/makara/pull/184) Andrew Kane
- Send advisory lock requests to the master [#198](https://github.com/instacart/makara/pull/198) George Claghorn
- Postgres exists query [#199](https://github.com/instacart/makara/pull/199) Brian Leonard

Documentation and Test
- Clarify README's "What goes where" [#187](https://github.com/instacart/makara/pull/187) Jan Sandbrink
- Fix loading fixtures in Rails 5.2 [#192](https://github.com/instacart/makara/pull/192) George Claghorn
- Travis Upgrade [#199](https://github.com/instacart/makara/pull/199) Brian Leonard

## v0.3.9 - 2017-08-14
[Full Changelog](https://github.com/instacart/makara/compare/v0.3.8...v0.3.9)

Changed
- Add postgis support [#118](https://github.com/instacart/makara/pull/118) Kevin Bacha

## v0.3.8 - 2017-07-11

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.7...v0.3.8)

Changed
- Rails 5.1 compatibility [#150](https://github.com/instacart/makara/pull/150) Jeremy Daer
- Minimize redundant context cache requests [#157](https://github.com/instacart/makara/issues/157) Greg Patrick
- thread-local cache for previous context stickiness [#158](https://github.com/instacart/makara/issues/158)  Jeremy Daer
- Configurable cookie options [#159](https://github.com/instacart/makara/pull/159) Jeremy Daer
- Test against Rails 5.x and Ruby 2.x [#160](https://github.com/instacart/makara/pull/160) Jeremy Daer

## v0.3.7 - 2016-09-22

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.6...v0.3.7)

Changed

- Fix the hierarchy of the config file [#116](https://github.com/instacart/makara/pull/116) Kevin Bacha
- "Disable blacklist" parameter [#134](https://github.com/instacart/makara/pull/134) Alex Tonkonozhenko
- Fixes bug in `without_sticking` [#96](https://github.com/instacart/makara/pull/96) Brian Leonard
- Always stick inside transactions [#96](https://github.com/instacart/makara/pull/96) Brian Leonard
- Rails 5 support [#122](https://github.com/instacart/makara/pull/122) Jonny McAllister

## v0.3.6 - 2016-04-21

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.5...v0.3.6)

Changed

- Allow different strategies such as `priority` and `round_robin` for pools [#105](https://github.com/instacart/makara/pull/105) Brian Leonard


## v0.3.5 - 2016-01-08

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.4.rc1...v0.3.5)

Changed

- Raise `Makara::Errors::AllConnectionsBlacklisted` on timeout. [#104](https://github.com/instacart/makara/pull/104) Brian Leonard

## v0.3.4.rc1 - 2016-01-06

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.3...v0.3.4.rc1)

Added

- Add `url` to database connections configurations. [#93](https://github.com/instacart/makara/pull/93) Benjamin Fleischer

Changed

- Improve Postgresql compatibility and failover support, also fix [#78](https://github.com/instacart/makara/issues/78), [#79](https://github.com/instacart/makara/issues/79). [#87](https://github.com/instacart/makara/pull/87) Vlad
- Update README: Specify newrelic_rpm gem versions that will have the performance issue. [#95](https://github.com/instacart/makara/pull/95) Benjamin Fleischer

## v0.3.3 - 2015-05-20

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.2...v0.3.3)

Changed

- A context is local to the curent thread of execution. This will allow you to stick to master safely in a single thread in systems such as sidekiq, for instance. Fix [#83](https://github.com/instacart/makara/issues/83). [#84](https://github.com/instacart/makara/pull/84) Matt Camuto

## v0.3.2 - 2015-05-16

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.1...v0.3.2)

Fixed

- Fix a `ArgumentError: not delegated` error for rails 3. [#82](https://github.com/instacart/makara/pull/82) Eric Saxby

Changed

- Switch log format from `:info` to `:error`. Mike Nelson

## v0.3.1 - 2015-05-08

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.0...v0.3.1)

Changed

- Globally move to multiline matchers. Mike Nelson

Changed

## v0.3.0 - 2015-04-27

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.0.rc3...v0.3.0)

Changed

- Reduce logging noise by using [the same rules as ActiveRecord uses](https://github.com/rails/rails/blob/b06f64c3480cd389d14618540d62da4978918af0/activerecord/lib/active_record/log_subscriber.rb#L33). [#76](https://github.com/instacart/makara/pull/76) Andrew Kane

Fixed

- Fix an issue for postgres that would route all queries to master. [#72](https://github.com/instacart/makara/pull/72) Kali Donovan
- Fix an edge case which would cause SET operations to send to all connections([#70](https://github.com/instacart/makara/issues/70)). [#80](https://github.com/instacart/makara/pull/80) Michael Amor Righi
- Fix performance regression with certain verions of [newrelic/rpm](https://github.com/newrelic/rpm)([#59](https://github.com/instacart/makara/issues/59)). [#75](https://github.com/instacart/makara/pull/75) Mike Nelson

## 0.3.0.rc3 - 2014-09-02[YANKED]

[Full Changelog](https://github.com/instacart/makara/compare/v0.3.0.rc2...v0.3.0.rc3)

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
