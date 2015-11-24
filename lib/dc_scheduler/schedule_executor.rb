module DcScheduler
##
# All schedule executors should inherit this class
  class ScheduleExecutor

    def initialize(schedule_id, makeup=false)
      @schedule_id = schedule_id
      @schedule = Schedule.find @schedule_id
      @schedule_data = @schedule.data
      @makeup = makeup
      @has_error = false
      @has_success = false
      @idx = 0
    end

    def call(job, time)
      before_tenant = Apartment::Tenant.current
      begin
        # Note that tenant attribute is dynamically attached to scheduler instance when initialized
        Apartment::Tenant.switch! job.scheduler.tenant
        @schedule = Schedule.find @schedule_id
        # Create schedule_execution
        @schedule_execution = @schedule.executions.new
        @schedule_execution.status = Constants::SCHEDULE_EXECUTION_INITIALIZING
        @schedule_execution.started_at = Time.now
        @schedule_execution.makeup = @makeup
        @schedule_execution.item_count = 0
        @schedule_execution.successful_count = 0
        @schedule_execution.failed_count = 0
        @schedule_execution.save!
        begin
          @execution_data = execution_data
          @schedule_execution.data = @execution_data ? @execution_data : nil
          @schedule_execution.status = Constants::SCHEDULE_EXECUTION_RUNNING
        rescue
          @schedule_execution.status = Constants::SCHEDULE_EXECUTION_INIT_FAILED
          raise Exceptions::ScheduleExecutionInitError,
                'Schedule execution initialization failed! Tenant is: ' +
                    "#{Apartment::Tenant.current}, schedule_execution id is: " +
                    "#{@schedule_execution.id}. Original error is: #{$!.message}. Trace is: ",
                $!.backtrace
        ensure
          @schedule_execution.save!
        end

        begin
          execute job, time
          if @schedule.delegated
            # If nothing to execute, directly update status to successful
            if @schedule_execution.item_count == 0
              @schedule_execution.status = Constants::SCHEDULE_EXECUTION_SUCCESSFUL
              @schedule_execution.finished_at = Time.now
            end
          else
            if !@has_error
              status = Constants::SCHEDULE_EXECUTION_SUCCESSFUL
            elsif @has_success
              status = Constants::SCHEDULE_EXECUTION_PARTIALLY_SUCCESSFUL
            else
              status = Constants::SCHEDULE_EXECUTION_FAILED
            end
            @schedule_execution.status = status
          end
        rescue
          @schedule_execution.status = Constants::SCHEDULE_EXECUTION_FAILED
          raise Exceptions::ScheduleExecutionInitError,
                'Schedule execution failed! Tenant is: ' +
                    "#{Apartment::Tenant.current}, schedule_execution id is: " +
                    "#{@schedule_execution.id}. Original error is: #{$!.message}. Trace is: ", $!.backtrace
        ensure
          @schedule_execution.finished_at = Time.now unless @schedule.delegated
          @schedule_execution.save!
        end
      rescue
        Rollbar.error $!
        Rails.logger.error $!
        raise $!
      ensure
        Apartment::Tenant.switch! before_tenant
      end
    end

    protected
    ##
    # Should be overridden by child class
    def execute(job, time)
    end

    ##
    # Convenient enqueue method, encapsulating current tenant and schedule_execution_id
    def enqueue(job_klass, *args)
      Resque.enqueue job_klass, Apartment::Tenant.current, @schedule_execution.id, @idx+=1, *args
    end

    ##
    # Could be overridden by child class to provide different execution data
    # For example, execution data may be dependent on current time, etc
    def execution_data
      @schedule_data
    end
  end
end