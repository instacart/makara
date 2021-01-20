module Makara
  module Cookie
    extend self

    IDENTIFIER = '_mkra_stck'.freeze

    DEFAULT_OPTIONS = {
      path: "/",
      http_only: true
    }

    MAX_AGE_BUFFER = 5

    def fetch(request)
      parse(request.cookies[IDENTIFIER].to_s)
    end

    def store(context_data, headers, options = {})
      unless context_data.nil?
        Rack::Utils.set_cookie_header! headers, IDENTIFIER, build_cookie(context_data, options)
      end
    end

    private

    # Pairs of {proxy_id}:{timestamp}, separated by "|"
    # proxy_id1:1518270031.3132212|proxy_id2:1518270030.313232 ..
    def parse(cookie_string)
      return {} if cookie_string.empty?

      states = cookie_string.split("|")
      states.each_with_object({}) do |state, context_data|
        proxy_id, timestamp = state.split(":")
        context_data[proxy_id] = timestamp.to_f if proxy_id && timestamp
      end
    end

    def build_cookie(context_data, options)
      cookie = DEFAULT_OPTIONS.merge(options)
      now = Time.now

      cookie[:max_age] = if context_data.any?
        (context_data.values.max - now.to_f).ceil + MAX_AGE_BUFFER
      else
        0
      end
      cookie[:expires] = now + cookie[:max_age]
      cookie[:value] = context_data.collect { |proxy_id, ttl| "#{proxy_id}:#{ttl}" }.join('|')

      cookie
    end
  end
end
