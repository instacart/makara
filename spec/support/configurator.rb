module Configurator
  def config(masters = 1, slaves = 2)
    connections = []
    masters.times{ connections << {:role => 'master'} }
    slaves.times{ connections << {:role => 'slave'} }
    {
      :makara => {
        :blacklist_duration => 30,
        :connections => connections
      }
    }
  end
end
