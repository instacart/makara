require 'makara/errors/invalid_shard'

module Makara
  module Strategies
    class ShardAware < ::Makara::Strategies::Abstract
      def init
        @shards = {}
        @default_shard = pool.default_shard
      end

      def connection_added(wrapper)
        id = wrapper._makara_shard_id
        shard_strategy(id).connection_added(wrapper)
      end

      def shard_strategy(shard_id)
        id = shard_id
        shard_strategy = @shards[id]
        unless shard_strategy
          shard_strategy = pool.shard_strategy_class.new(pool)
          @shards[id] = shard_strategy
        end
        shard_strategy
      end

      def current
        id = shard_id
        raise Makara::Errors::InvalidShard.new(pool.role, id) unless id && @shards[id]

        @shards[id].current
      end

      def next
        id = shard_id
        raise Makara::Errors::InvalidShard.new(pool.role, id) unless id && @shards[id]

        @shards[id].next
      end

      def shard_id
        Thread.current['makara_shard_id'] || pool.default_shard
      end
    end
  end
end
