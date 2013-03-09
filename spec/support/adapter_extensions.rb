module AdapterExtensions

  def master_group
    @master
  end

  def slave_group
    @slave
  end

  def stuck?
    self.currently_stuck?
  end
  
  def master_only?
    @slave.length == 0
  end

  def slaved?(count = nil)
    return @slave.length > 0 if count.nil?
    @slave.length == count
  end

  def master(number = 1)
    @master.instance_variable_get('@wrappers')[number - 1]
  end

  def mcon(number = 1)
    master(number).connection
  end

  def slave(number = 1)
    @slave.instance_variable_get('@wrappers')[number - 1]
  end

  def scon(number = 1)
    slave(number).connection
  end

  def wrapper_of_choice(sql)
    current_wrapper_for(sql)
  end

  def sticky_slaves?
    @sticky_slave
  end

  def sticky_master?
    @sticky_master
  end

end

require 'active_record/connection_adapters/makara_adapter'
ActiveRecord::ConnectionAdapters::MakaraAdapter.send(:include, AdapterExtensions)

module WrapperExtensions

  def config
    @config
  end

end

Makara::Connection::Wrapper.send(:include, WrapperExtensions)