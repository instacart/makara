module Makara
  class ConnectionList

    SQL_KEYWORDS = %w(explain update insert delete)
    SQL_EXPRESSION = /#{SQL_KEYWORDS.join('|')}/

    def initialize(config = {})

      @sticky_master = true
      @sticky_master = !!config.delete(:sticky_master) if config.has_key?(:sticky_master)

      @sticky_slaves = true
      @sticky_slaves = !!config.delete(:sticky_slaves) if config.has_key?(:sticky_slaves)

      @master = extract_connection_from_config(config, 'master', true)
      @slaves = extract_slaves_from_config(config)
      
    end

    def execute(sql, name = nil)
      wrapper = current_wrapper_for(sql)
      stick!(wrapper) if should_stick?(wrapper)
      wrapper.execute(sql, name)
    end

    def connection_wrapper_for(sql)
      return @master if requires_master?(sql)
      @stuck_on || @slaves.next || @master
    end

    def unstick!
      @stuck_on = nil
    end

    def sticky_slave?
      !!@sticky_slaves
    end
    alias_method :sticky_slaves?, :slicky_slave

    def sticky_master?
      !!@sticky_master
    end


    protected

    def stick!(wrapper)
      @stuck_on = wrapper
    end

    def currently_stuck?
      !!@stuck_on
    end

    def should_stick?(wrapper)
      return false if currently_stuck?
      return true if wrapper.master? && sticky_master?
      return true if wrapper.slave? && sticky_slave?
      false
    end

    def requires_master?(sql)
      sql.downcase =~ SQL_EXPRESSION
    end

    def extract_connection_from_config(config, default_name = nil, is_master = false)
      adapter_config = extract_base_config(config)

      name = adapter_config.delete(:name) || default_name || 'adapter'
      adapter_method = "#{adapter_config[:adapter]}_connection"

      klazz = (is_master ? ::Makara::ConnectionWrapper::MasterWrapper : ::Makara::ConnectionWrapper::SlaveWrapper)
      klazz.new(name, ConnectionSpecification.new(adapter_config, adapter_method))
    end

    def extract_slaves_from_config(config)
      i = 0
      base_config = extract_base_config(config)

      [*config[:slaves]].compact.map do |slave_config|
        i += 1
        slave_config = slave_config.reverse_merge(base_config)
        extract_connection_from_config(slave_config, "slave_#{i}", false)
      end

    end

    def extract_base_config(whole)
      whole = whole.symbolize_keys
      whole.except(:slaves, :sticky_slaves, :sticky_master)
    end

  end
end
