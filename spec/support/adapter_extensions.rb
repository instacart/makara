module AdapterExtensions

  def master_only?
    @slaves.blank?
  end

  def slaved?(count = nil)
    return @slaves.present? if count.nil?
    @slaves.length == count
  end

  def slaves
    @slaves
  end

  def master
    @master
  end

  def mcon
    master.connection
  end

  def slave(number = 1)
    @slaves[number - 1]
  end

  def scon(number = 1)
    slave(number).connection
  end

  def slave_connection
    slave(number).connection
  end

  def wrapper_of_choice(sql)
    current_wrapper_for(sql)
  end

  def sticky_slaves?
    @sticky_slaves
  end

  def sticky_master?
    @sticky_master
  end

end

ActiveRecord::ConnectionAdapters::MakaraAdapter.send(:include, AdapterExtensions)

module WrapperExtensions

  def config
    @config
  end

end

Makara::ConnectionWrapper::AbstractWrapper.send(:include, WrapperExtensions)