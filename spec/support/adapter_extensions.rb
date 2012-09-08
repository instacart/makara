module AdapterExtensions

  def master_only?
    @slaves.blank?
  end

  def master
    @master
  end

  def master_connection
    master.connection
  end

  def slave(number)
    @slaves[number]
  end

  def slave_connection
    slave(number).connection
  end

  def wrapper_of_choice(sql)
    current_wrapper_for(sql)
  end

end

ActiveRecord::ConnectionAdapters::MakaraAdapter.send(:include, AdapterExtensions)