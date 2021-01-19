module Makara
  module Errors
    class InvalidShard < MakaraError
      attr_reader :role
      attr_reader :shard_id

      def initialize(role, shard_id)
        @role = role
        @shard_id = shard_id
        super "[Makara] Invalid shard_id #{shard_id} for the #{role} pool"
      end
    end
  end
end
