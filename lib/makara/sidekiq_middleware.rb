# Makes sure each Sidekiq job starts fresh regarding Makara variables.
# Makes it so only jobs with sidekiq_options read_from_slave: true will be able to read from slave
# (Makara.force_slave will however always send queries to slave)
module Makara
  class SidekiqMiddleware
    def call(worker_class, msg, queue)
      # Set this sidekiq_option if you want the worker to be able to read from slave
      # Otherwise, we just read from master
      Makara.stick_to_master! unless msg["read_from_slave"]
      yield
    ensure
      # Clear the thread variables related to Makara
      Makara::Context.set_current(nil)
      Makara::Context.clear_stick_to_master_until
    end
  end
end
