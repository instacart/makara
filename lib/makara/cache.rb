module Makara
  module Cache
    class << self
      def store=(store)
        Makara::Logging::Logger.log deprecation_warning, :warn
      end

      private

      def deprecation_warning
        "Makara's context is no longer persisted in a backend cache, a cookie store is used by default.\nSetting the Makara::Cache.store won't have any effects."
      end
    end
  end
end
