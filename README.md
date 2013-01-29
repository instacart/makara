# Makara: *A Read-Write splitting adaptor for Active Record*

[![Build Status](https://secure.travis-ci.org/taskrabbit/makara.png)](http://travis-ci.org/taskrabbit/makara)

## What?

Makara allows your Rails applications to use read-write splitting to share the load across multiple database servers. 

Read-Write splitting is the notion that if you have synchronized database, you can send all "write queries" (insert, update, delete) to a master database, and perform all of your "read queries" (select) from a number of slaves.  As most Rails applications are read-heavy, this scaling practice is very desirable.
 
## Features

* Read/Write splitting across multiple databases
* Failover upon slave errors/loss
* Automatic reconnection attempts to lost slaves
* Optional "sticky" connections to master and slaves
* Works with many database types (mysql, postgres, etc)
* Provides a middleware for releasing stuck connections
* Multi-request stickiness via cookies
* Weighted connection pooling for connection priority

## Quick Start

Add makara to your gemfile:

    gem 'makara'

[Configure your database.yml](./DATABASE_YML_CONFIG.md) as desired.
  
    production:
      sticky_slave: true
      sticky_master: true

      adapter: makara
      
      db_adapter: mysql2
      host: xxx
      user: xxx
      password: xxx
      blacklist_duration: 5
      
      databases:
        - name: master
          role: master
        - name: slave1
          role: slave
          host: xxx
          user: xxx
          password: xxx
          weight: 3
        - name: slave2
          role: slave
          host: xxx
          user: xxx
          weight: 2

Profit.

## What is a sticky connection?

Often times your application will write data and then quickly read it back (user registration is the classic example).  It it is possible that your stack may perform faster than your database synchronization (especially across geographies).  In this case, you may opt to hold "sticky" connections to ensure that for the remainder of a request, your web-worker (Thin, Mongrel, Unicorn, etc) continues utilizing the node it had been previously reading from to ensure a consistent experience. 

Makara makes use of cookies to ensure that requests which have just updated a record will read from the database they just wrote to in the following request. This avoids reading from a slave which may not have synced the new data yet.

## Failover

If an error is raised while attempting a query on a slave, the query will be retried on another slave (or the master DB), and the slave with the error will be blacklisted.  Every so often, Makara will attempt to reconnect to these lost slaves.  This ensures the highest possible uptime for your application.

In your [database.yml](./DATABASE_YML_CONFIG.md), you can define a `blacklist_duration` to set how often lost connections are retried (default is 1 minute).  Unfortunately, there is no failover if your master database goes down.

## Questions

- Can I have more than one master database?
  - Yes!  You can define many slave and master roles. Be sure that your database replication is configured to handle multiple masters if you desire multi-master functionality.
- Can I use Makara for my Rails 2 project?
  - Nope.  However, there are other project that [work well for Rails 2](https://github.com/tchandy/octopus) 
  - Also, feel free to submit a pull request.
- Does Makara handle geographic selection of databases?
  - No, but you can load up a separate database.yml file for each location
- Does Makara solve all my performance problems.
  - Yes! Actually, no.

For more information, you can [http://tech.taskrabbit.com/blog/2013/01/02/makara/](read our launch announcment on our blog)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## Acknowledgements

- Makara was developed by the fine folks at [www.taskrabbit.com](http://www.taskrabbit.com).  If you like working on problems like this one, [we are hiring](http://www.taskrabbit.com/careers).
- The [Octopus Gem](https://github.com/tchandy/octopus) inspired our work on this project (including the name).  We have [a fork](https://github.com/taskrabbit/octopus/compare/master) which adds some of the failover features Makara has.
