module DcScheduler
  module Utils
    class << self
      def valid_crontab?(crontab)
        CronParser.new crontab rescue return false
        true
      end
    end
  end
end