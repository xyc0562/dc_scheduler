module DcScheduler
  module Exceptions
    # A general exception
    class Error < StandardError
      attr_accessor :tenant
      def initialize(msg=nil, backtrace=nil)
        @tenant = Apartment::Tenant.current
        msg = "Tenant `#{@tenant}`: #{msg}"
        e = super msg
        if backtrace
          e.set_backtrace backtrace
        end
        e
      end
    end
    # Exceptions related to scheduler
    class ScheduleError < Error; end
    class ScheduleExecutionInitError < ScheduleError; end
    class ScheduleExecutionError < ScheduleError; end
    class ScheduleCreationError < ScheduleError; end
  end
end