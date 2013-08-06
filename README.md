# Makara: *A Read-Write splitting adaptor for Active Record*

[![Build Status](https://secure.travis-ci.org/taskrabbit/makara.png)](http://travis-ci.org/taskrabbit/makara)
[![Code Climate](https://codeclimate.com/github/taskrabbit/makara.png)](https://codeclimate.com/github/taskrabbit/makara)

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
* Multi-connection compatability

## Quick Start

Add makara to your gemfile:

    gem 'makara', git: 'git@github.com:taskrabbit/makara.git', tag: 'v0.1.0'

Configure your database.yml as desired.
  
    production:
      id: 'my_app'

      sticky_slave: true
      sticky_master: true

      adapter: makara_mysql2
      
      host: xxx
      user: xxx
      password: xxx
      blacklist_duration: 5
      
      connections:
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

Makara by default makes use of cookies to ensure that requests which have just updated a record will read from the database they just wrote to in the following request. This avoids reading from a slave which may not have synced the new data yet. No connection information is stored in the cookie, simply an integer representing the index of the adapter in your app. If you'd like to use a different storage mechanism, you can - just provide it as the `state_cache_store` in  your database.yml (see below).

## Failover

If an error is raised while attempting a query on a slave, the query will be retried on another slave (or the master DB), and the slave with the error will be blacklisted.  Every so often, Makara will attempt to reconnect to these lost slaves.  This ensures the highest possible uptime for your application.

In your database.yml, you can define a `blacklist_duration` to set how often lost connections are retried (default is 1 minute).  Unfortunately, there is no failover if your master database goes down.


# Usage

Makara is designed to be configured solely via your `database.yml`. This means there are no initializers, there are no race conditions, and deployments are not impacted by using Makara.

## Configuring your database.yml

The minimal `database.yml` you'll need to get things running looks like (optional defaults exposed):

    production:
      adapter: makara_mysql2

      id: default                 // optional
      namespace: ~                // optional
      sticky_master: true         // optional
      sticky_slaves: true         // optional
      blacklist_duration: 60      // optional
      verbose: false              // optional

      database: my_project_db
      username: root
      password: 

      connections:
        - name: master
          role: master

To define a slave connection, provide another connection with either the role removed or as `slave`.

    production:
      ...
      connections:
        - name: master
          role: master
        - name: slave 1

By default the connections will inherit the top-level connection configuration. The best practice is to put the shared options in the top-level and define all the differences in each sub-config. In the example below, the `db_adapter`, `username`, and `password` options will be shared among all the connections.

    production:
      adapter: makara_mysql2
      username: the-user
      password: the-password

      connections:
        - name: master
          role: master
          database: prod-db-master
        - name: slave 1
          database: prod-db-slave-1
        - name: slave 2
          database: prod-db-slave-2

## Configuration options

The following are definitions of the options available to the makara adapter:
  
* id
  - [string]
  - [optional for single connection apps]
  - the name used to identify this adapter. 
  - if multiple connections use makara, this must be unique
    
* blacklist_duration:
  - [integer]
  - the number of seconds a node is blacklisted before attempting a reconnect
  - can be configured globally or on a per-db basis

* state_cache_store
  - [string or symbol]
  - provides the class name, or the symbol of the class that should be used as the state cache store.

* state_cache
  - [hash]
  - provides any connection information needed for your state cache store of choice. (optional)

* sticky_master:
  - [boolean]
  - once a master connection is used, it will continue using that connection until the adapter is told to `unstick!`
  - takes priority over sticky_slave

* sticky_slave:
  - [boolean]
  - once a slave connection is read from, it will continue using that connection until the adapter is told to `unstick!`

* verbose
  - [boolean]
  - whether the makara adapter should log information about it's decisions

* name
  - [string]
  - [per-db]
  - the name used to identify this underlying connection. 
  - should be unique

* role
  - [string]
  - [per-db, optional for slaves]
  - the role this connection should take on (master or slave)
  - if ommitted, assumed to be slave

## State Caches

To ensure consistency, the makara middleware will try to use a cache between requests to store which connections should be forced to master on the next request. It uses the cookie store by default but you have the option to use others. You can tell Makara which store to use via your database.yml:

    production:
      state_cache_store: :rails

The previous config would use the ::Makara::StateCaches::Rails class to store the information. Keep in mind the data expires in 5 seconds, so it's generally not something to worry about. A more complex config is as follows:

    production:
      state_cache_store: :redis
      state_cache:
        :host: '127.0.0.1'
        :port: 6380

In the case of the redis store, if no config options are provided, `Redis.current` will be used. If you want to write a custom store, inherit from ::Makara::StateCaches::Abstract and declare it in your database.yml:

    production:
      state_cache_store: 'MyCustom::Store'

Notice that when the store is provided as a :symbol it will load the constant from within ::Makara::StateCaches

## Rake Tasks and Other Master-Only Usage

In some cases, such as rake tasks or workers, it's preferred to lock Makara to master to avoid replication lag. To force master on all connections, all you need to do is `Makara.force_master!`. If you only want master forced on a specific connection, you can access it through the `Makara.adapters` and force via `adapter.force_master!`.

### Rakefile setup

    # Rakefile
    ENV['lock_makara_to_master'] = 'true'
    
    # config/initializers/makara.rb
    require 'makara'
    if ENV["lock_makara_to_master"] == "true"
      Makara.force_master!
      puts "Locked Makara to master for all connections"
    end




## Questions

- Can I have more than one master database?
  - Yes!  You can define many slave and master roles. Be sure that your database replication is configured to handle multiple masters if you desire multi-master functionality.
- Can I have multiple connections configured (to different db's or clusters)?
  - Yes!  Each top-level adapter is handled safely in the context of it's connection specified in it's database.yml.
- Can I use Makara for my Rails 2 project?
  - Nope.  However, there are other project that [work well for Rails 2](https://github.com/tchandy/octopus) 
  - Also, feel free to submit a pull request.
- Does Makara handle geographic selection of databases?
  - No, but you can load up a separate database.yml file for each location
- Does Makara solve all my performance problems.
  - Yes! Actually, no.

For more information on TaskRabbit, [check out our tech blog](http://tech.taskrabbit.com/)

## Contributing

1. Fork it
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Added some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create new Pull Request


## Acknowledgements

- Makara was developed by the fine folks at [www.taskrabbit.com](http://www.taskrabbit.com).  If you like working on problems like this one, [we are hiring](http://www.taskrabbit.com/careers).
- The [Octopus Gem](https://github.com/tchandy/octopus) inspired our work on this project (including the name).  We have [a fork](https://github.com/taskrabbit/octopus/compare/master) which adds some of the failover features Makara has.
