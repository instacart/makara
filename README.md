# Makara

[![Build Status](https://travis-ci.org/taskrabbit/makara.png?branch=master)](https://travis-ci.org/taskrabbit/makara)
[![Code Climate](https://codeclimate.com/repos/526886a7f3ea00679b00cae6/badges/7905f7a000492a1078f7/gpa.png)](https://codeclimate.com/repos/526886a7f3ea00679b00cae6/feed)


Makara is generic master/slave proxy. It handles the heavy lifting of managing, choosing, blacklisting, and cycling through connections. It comes with an ActiveRecord database adapter implementation.

#### Warning:

There is a potential performance issue when used alongside certain versions of [newrelic/rpm](https://github.com/newrelic/rpm). Read more and contribute data [here](https://github.com/taskrabbit/makara/issues/59).

## Installation

```ruby
gem 'makara', github: 'taskrabbit/makara', tag: 'v0.3.x'
```

## Basic Usage

If you're only interested in the ActiveRecord database adapter... [here you go.](#activerecord-database-adapter)

Makara provides a base proxy class which you should inherit from. Your proxy connection class should implement a `connection_for` instance method which will be provided with an individual configuration and expect a real connection back.

```ruby
class MyAwesomeSqlProxy < ::Makara::Proxy
  def connection_for(config)
    ::Sql::Client.new(config)
  end
end
```

Next, you need to decide which methods are proxied and which methods should be sent to all underlying connections:

```ruby
  # within MyAwesomeSqlProxy
  hijack_method :select, :ping
  send_to_all :connect, :reconnect, :disconnect, :clear_cache
```

Assuming you don't need to split requests between a master and a slave, you're done. If you do need to, implement the `needs_master?` method:

```ruby
  # within MyAwesomeSqlProxy
  def needs_master?(method_name, args)
    return false if args.empty?
    sql = args.first
    sql !~ /^select/i
  end
```

This implementation will send any request not like "SELECT..." to a master connection. There are more methods you can override and more control over blacklisting - check out the [makara database adapter](lib/active_record/connection_adapters/makara_abstract_adapter.rb) for examples of advanced usage.

### Config Parsing

Makara comes with a config parser which will handle providing subconfigs to the `connection_for` method. Check out the ActiveRecord database.yml example below for more info.

### Context

Makara handles stickyness by keeping track of a context (sha). In a multi-instance environment it persists a context in a cache. If Rails is present it will automatically use Rails.cache. You can provide any kind of store as long as it responds to the methods required in [lib/makara/cache.rb](lib/makara/cache.rb).

```ruby
Makara::Cache.store = MyRedisCacheStore.new
```

To handle persistence of context across requests in a Rack app, makara provides a middleware. It lays a cookie named `_mkra_ctxt` which contains the current master context. If the next request is executed before the cookie expires, master will be used. If something occurs which naturally requires master on the second request, the context is changed and stored again.

#### Changing Context

If you need to change the makara context, releasing any stuck connections, all you have to do is:

```ruby
ctx = Makara::Context.generate # or any unique sha
Makara::Context.set_current ctx
```


### Forcing Master

If you need to force master in your app then you can simply invoke stick_to_master! on your connection:

```ruby
write_to_cache = true # or false
proxy.stick_to_master!(write_to_cache)
```


### Skipping the Stickiness

If you're using the `sticky: true` configuration and you find yourself in a situation where you need to write information through the proxy but you don't want the context to be stuck to master, you should use a `without_sticking` block:

```ruby
proxy.without_sticking do
  # do my stuff that would normally cause the proxy to stick to master
end
```

### Logging

You can set a logger instance to ::Makara::Logging::Logger.logger and Makara will log how it handles errors at the Proxy level.

```ruby
Makara::Logging::Logger.logger = ::Logger.new(STDOUT)
```

## ActiveRecord Database Adapter

So you've found yourself with an ActiveRecord-based project which is starting to get some traffic and you realize 95% of you DB load is from reads. Well you've come to the right spot. Makara is a great solution to break up that load not only between master and slave but potentially multiple masters and/or multiple slaves.

By creating a makara database adapter which simply acts as a proxy we avoid any major complexity surrounding specific database implementations. The makara adapter doesn't care if the underlying connection is mysql, postgresql, etc it simply cares about the sql string being executed.

### What goes where?

Any `SELECT` statements will execute against your slave(s), anything else will go to master. The only edge case is `SET` operations which are sent to all connections. Execution of specific methods such as `connect!`, `disconnect!`, and `clear_cache!` are invoked on all underlying connections.

### Errors / blacklisting

Whenever a node fails an operation due to a connection issue, it is blacklisted for the amount of time specified in your database.yml. After that amount of time has passed, the connection will begin receiving queries again. If all slave nodes are blacklisted, the master connection will begin receiving read queries as if it were a slave. Once all nodes are blacklisted the error is raised to the application and all nodes are whitelisted.

### Database.yml

Your database.yml should contain the following structure:

```yml
production:
  adapter: 'mysql2_makara'
  database: 'MyAppProduction'
  # any other standard AR configurations

  # add a makara subconfig
  makara:

    # the following are default values
    blacklist_duration: 5
    master_ttl: 5
    sticky: true

    # list your connections with the override values (they're merged into the top-level config)
    # be sure to provide the role if master, role is assumed to be a slave if not provided
    connections:
      - role: master
        host: master.sql.host
      - role: slave
        host: slave1.sql.host
      - role: slave
        host: slave2.sql.host
```

Let's break this down a little bit. At the top level of your config you have the standard `adapter` choice. Currently the available adapters are listed in [lib/active_record/connection_adapters/](lib/active_record/connection_adapters/). They are in the form of `#{db_type}_makara` where db_type is mysql, postgresql, etc.

Following the adapter choice is all the standard configurations (host, port, retry, database, username, password, etc). With all the standard configurations provided, you can now provide the makara subconfig.

The makara subconfig sets up the proxy with a few of its own options, then provides the connection list. The makara options are:
* blacklist_duration - the number of seconds a node is blacklisted when a connection failure occurs
* sticky - if a node should be stuck to once it's used during a specific context
* master_ttl - how long the master context is persisted. generally, this needs to be longer than any replication lag
* connection_error_matchers - array of custom error matchers you want to be handled gracefully by Makara (as in, errors matching these regexes will result in blacklisting the connection as opposed to raising directly).

Connection definitions contain any extra node-specific configurations. If the node should behave as a master you must provide `role: master`. Any previous configurations can be overridden within a specific node's config. Nodes can also contain weights if you'd like to balance usage based on hardware specifications. Optionally, you can provide a name attribute which will be used in sql logging.

```yml
connections:
  - role: master
    host: mymaster.sql.host
    blacklist_duration: 0

  # implicit role: slave
  - host: mybigslave.sql.host
    weight: 8
    name: Big Slave
  - host: mysmallslave.sql.host
    weight: 2
    name: Small Slave
```

In the previous config the "Big Slave" would receive ~80% of traffic.

## Custom error matchers:

To enable Makara to catch and handle custom errors gracefully (blacklist the connection instead of raising directly), you must add your custom matchers to the `connection_error_matchers` setting of your config file, for example:

```yml
production:
  adapter: 'mysql2_makara'

  makara:
    blacklist_duration: 5
    connection_error_matchers:
      - !ruby/regexp '/^ActiveRecord::StatementInvalid: Mysql2::Error: Unknown command:/'
      - '/Sql Server Has Gone Away/'
      - 'Mysql2::Error: Duplicate entry'
```

You can provide strings or regexes.  In the case of strings, if they start with `/` and end with `/` they will be converted to regexes when evaluated. Strings that don't start and end with `/` will get evaluated with standard comparison.

## Common Problems / Solutions

On occasion your app may deal with a situation where makara is not present during a write but a read should use master. In the generic proxy details above you are encouraged to use `stick_to_master!` to accomplish this. Here's an example:

```ruby
# some third party creates a resource in your db, slave replication may not have completed yet
# ...
# then your app is told to read the resource.
def handle_request_after_third_party_record_creation
  CreatedResourceClass.connection.stick_to_master!
  CreatedResourceClass.find(params[:id]) # will go to master
end
```

Similarly, if you have a third party service which will conduct a generic request against your Rack app, you can force master via a query param:

```ruby
def send_url_to_third_party
  context = Makara::Context.get_current
  ThirdParty.read_from_here!("http://mysite.com/path/to/resource?_mkra_ctxt=#{context}")
end
```

## Todo

* Cookie based cache store?
* More real world examples
