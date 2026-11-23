module Discourse
  # Keeps us polite: at most one request per `interval` seconds.
  # The clock and sleeper are injected so specs run instantly.
  class Throttle
    def initialize(interval: 1.0, clock: -> { Process.clock_gettime(Process::CLOCK_MONOTONIC) }, sleeper: ->(s) { sleep(s) })
      @interval = interval
      @clock = clock
      @sleeper = sleeper
      @last_at = nil
    end

    def wait!
      if @last_at
        remaining = @interval - (@clock.call - @last_at)
        @sleeper.call(remaining) if remaining.positive?
      end
      @last_at = @clock.call
    end
  end
end
