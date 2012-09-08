module Makara
  module ConnectionWrapper

    autoload :AbstractWrapper,     'makara/connection_wrapper/abstract_wrapper'
    autoload :MasterWrapper,       'makara/connection_wrapper/master_wrapper'
    autoload :SlaveWrapper,        'makara/connection_wrapper/slave_wrapper'
    
    autoload :ConnectionDecorator, 'makara/connection_wrapper/connection_decorator'
  end
end