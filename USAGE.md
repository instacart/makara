# Makara Usage

Makara is designed to be configured solely via your `database.yml`. This means there are no initializers, there are no race conditions, and deployments are not impacted by using Makara.

## Configuring your database.yml

The minimal `database.yml` you'll need to get things running looks like (optional defaults exposed):

    production:
      adapter: makara

      id: default                 // optional
      namespace: ~                // optional
      sticky_master: true         // optional
      sticky_slaves: true         // optional
      blacklist_duration: 60      // optional
      verbose: false              // optional

      db_adapter: mysql2
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
      adapter: makara
      db_adapter: mysql2
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