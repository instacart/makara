# Change Log
All notable changes to this project will be documented in this file.

## 0.3.0rc2 - 2014-08-05
### Added
- allow bypassing of stickiness

## 0.3.0rc2 - 2014-08-05
### Added
- add postgres specific tests.

### Changed
- change using methods for matchers to be able to monkey patch them
- follow AR naming conventions for adapter naming

## 0.3.0rc1 - 2014-08-05
### Removed
- removed initial connection logic. If a connection can't be made on startup, an error will be thrown rather than the node getting blacklisted.


## 0.2.2 - 2014-04-03
### Added
- add logging of makara operations via the Makara::Logger

### Changed
- begin tracing the series of errors associated with blacklisting rather than just the last. This becomes apparent in error messages.
- fix Rails.cache usage when full environment is not loaded.
