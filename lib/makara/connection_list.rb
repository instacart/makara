module Makara
  class ConnectionList

    SQL_KEYWORDS = ['explain', 'update', 'insert', 'delete', 'show tables']
    SQL_EXPRESSION = /#{SQL_KEYWORDS.join('|')}/


    # Create a connection list. This intercepts database adapter's execute() calls to reroute to the appropriate database
    # based on the database.yml you can force any connection to be "sticky". By default sticky is set to true for both
    # the master and the slaves. This is guard against retrieving of stale or out-of-sync data.
    def initialize(config = {})

      @sticky_master = true
      @sticky_master = !!config.delete(:sticky_master) if config.has_key?(:sticky_master)

      @sticky_slaves = true
      @sticky_slaves = !!config.delete(:sticky_slaves) if config.has_key?(:sticky_slaves)

      @master = ::Makara::ConnectionBuilder.extract_connection_from_config(self, config, 'master', true)
      @slaves = ::Makara::ConnectionBuilder.extract_slaves_from_config(self, config)

      decorate_connections!

      @hijacking_execute = false

      reset_current_slave
    end

    # the execute method which routes it's call to the correct underlying adapter.
    # if we're already stuck on a connection, continue using it. if we want to be stuck on a connection, stick to it.
    # 
    def execute(sql, name = nil)
      
      # the connection wrapper that should handle the execute call
      wrapper = current_wrapper_for(sql)

      # stick to it if we determine that's the right thing to do
      stick!(wrapper) if should_stick?(wrapper)

      # mark ourselves as being in a hijack block so we don't invoke this execute() unecessarily
      hijacking_execute! do

        # hand off control to the wrapper
        wrapper.execute(sql, name)
      end

    # catch all exceptions for now, since we don't know what adapter we'll be using or how they'll be formatted
    rescue Exception => e
      
      # we caught this exception while invoking something on the master connection, raise the error
      raise e if wrapper.master?

      # let's blacklist this slave to ensure it's removed from the slave cycle
      wrapper.blacklist!

      # switch back to the start of our slave cycle and try again. if no slaves are left we'll use the master
      reset_current_slave
      
      # do it!
      retry
    end

    # if we want to unstick the current connection (request is over, testing, etc)
    def unstick!
      @stuck_on = nil
    end
    alias_method :release!, :unstick!

    # the game
    def stuck_on
      @stuck_on
    end

    # should we be sticking to slaves once they're invoked?
    def sticky_slave?
      !!@sticky_slaves
    end
    alias_method :sticky_slaves?, :slicky_slave?

    # should we stick with the master once it's invoked?
    def sticky_master?
      !!@sticky_master
    end

    # are we currently hijacking an execute call and choosing the appropriate connection?
    def hijacking_execute?
      !!@hijacking_execute
    end

    protected

    # the connection wrapper which should be chosen based on the sql we've provided.
    # if we're dealing with a sql statement which requires master access, use it.
    # otherwise, let's use the currently stuck connection, the next available slave, or the master connection
    def connection_wrapper_for(sql)
      return @master if requires_master?(sql)
      @stuck_on || next_slave || @master
    end

    # denote that we're hijacking an execute call
    def hijacking_execute!
      @hijacking_execute = true
      yield
    ensure
      @hijacking_execute = false
    end

    # we need a concept of the current slave for iteration purposes. this resets that current to the first slave
    def reset_current_slave
      @current_slave = @slaves.first
    end

    # get the next available slave. if none are available this will return nil
    def next_slave
      @current_slave.try(:next)
    end

    # let's get stuck on a wrapper so we continue utilizing the same connection for the duration of this request (or until we're unstuck)
    def stick!(wrapper)
      @stuck_on = wrapper
    end

    # are we currently stuck on a wrapper?
    def currently_stuck?
      !!@stuck_on
    end

    # given the wrapper and the current configuration, should we stick to this guy?
    # note: if all wrappers are sticky, we should stick to the master even if we've already stuck
    # to a slave.
    def should_stick?(wrapper)
      return true if wrapper.master? && sticky_master?
      return true if wrapper.slave? && sticky_slave?
      false
    end

    # based on this sql command, should we require the master connection be used?
    # override this if you'd like to globally set to master in a block
    def requires_master?(sql)
      !!(sql.to_s.downcase =~ SQL_EXPRESSION)
    end

    # decorate our database adapters to invoke our execute before they invoke their own
    def decorate_connections!
      decorate_connection(@master.connection)
      @slaves.each{|s| decorate_connection(s.connection) }
    end
    
    def decorate_connection(con)
      con.extend ::Makara::ConnectionWrapper::ConnectionDecorator
      con.connection_list = self
      con
    end


  end
end
