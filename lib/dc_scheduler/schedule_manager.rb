module DcScheduler
  module ScheduleManager
    class << self
      ##
      # This is actually creating a GLOBAL variable
      # Not sure if this is the best way of dealing with
      # this problem.
      def init_tenant_schedulers(all_tenants, options={})
        $_schedulers = Hash.new
        all_tenants.each do |tenant|
          scheduler = Rufus::Scheduler.new options
          # Dynamically attach tenant key to the scheduler
          class << scheduler
            attr_accessor :tenant
          end
          scheduler.tenant = tenant
          $_schedulers[tenant] = { scheduler: scheduler, job_mapping: {} }
        end
      end

      ##
      # Synchronize with database schedule, which includes:
      # 1. Make up for any missed schedule (if target schedule permits make-up)
      # 2. Send valid schedules to rufus (valid means not expired and currently active)
      # Note that synchronization is done for both global tenant and all client tenants
      def sync_schedule_for_tenants(all_tenants)
        cur_tenant = Apartment::Tenant.current
        begin
          all_tenants.each do |tenant|
            Apartment::Tenant.switch! tenant
            Rails.logger.info "Synchronizing DB schedules for tenant: `#{tenant}`"
            sync_schedule_current_tenant
            Rails.logger.info "Synchronizing DB schedules for tenant: `#{tenant}` is successful"
          end
        rescue
          Rollbar.error $!
          Rails.logger.error $!
        ensure
          Apartment::Tenant.switch! cur_tenant
        end
      end

      ##
      # Synchronize with database schedule for current tenant
      def sync_schedule_current_tenant
        schedules = Schedule.all_active_schedules
        schedules.each do |schedule|
          Rails.logger.info "Synchronizing schedule with id: #{schedule.id}"
          Rails.logger.debug "#{schedule.to_s}"
          last_trigger = schedule.last_trigger_at
          # If makeup is allowed and execution is overdue
          if schedule.allow_makeup && last_trigger &&
              (!schedule.last_execution_at && last_trigger.to_i > schedule.after.to_i ||
                  schedule.last_execution_at && schedule.last_execution_at.to_i < last_trigger.to_i)
            # Execute makeup schedule now
            # The reason for not directly invoking handler is that
            # Rufus takes care of threading for us
            register_schedule schedule, true
            Rails.logger.info "Makeup execution created for schedule with id: #{schedule.id}"
          end
          # Activate schedule if possible to execute in the future
          if (trigger = schedule.next_trigger_at)
            Rails.logger.info "Registered future trigger for schedule: #{schedule.id}, next_trigger_at: #{trigger}."
            register_schedule schedule
          end
        end
      end

      ##
      # Need to note that this method is not responsible for validating user input
      # Which means whoever calls it must make sure user does sensible things
      # such as not scheduling a point task in the past etc.
      # 1. Create schedule and insert into database
      # 2. Create job for rufus-scheduler
      # returns created schedule ORM object.
      def create_schedule(name, desc, executor_name, schedule_data, trigger_point, options={})
        options = {
            delegated: true,
            allow_makeup: false
        }.merge options
        allow_makeup = options[:allow_makeup]
        delegated = options[:delegated]
        # Entire operation should reside in single transaction
        schedule = Schedule.new
        ActiveRecord::Base.transaction do
          begin
            schedule.name = name
            schedule.description = desc
            schedule.executor_name= executor_name
            schedule.data = schedule_data ? schedule_data : nil
            schedule.delegated = delegated
            now = trigger_point.to_s == 'now'
            if now
              schedule.at = Time.now
            else
              trigger_point.class == String ? schedule.crontab = trigger_point : schedule.at = trigger_point
            end
            schedule.active = true
            schedule.after = Time.now
            schedule.allow_makeup = allow_makeup
            if block_given?
              yield schedule
            end
            schedule.save!
            # Continue to create and store job
            register_schedule schedule, now
            Rails.logger.info "Created schedule: #{schedule.to_s}. Next trigger is: #{schedule.next_trigger_at}."
          rescue
            Rollbar.error $!
            Rails.logger.error $!
            # Rethrow exception
            raise $!
          end
        end
        schedule
      end

      def register_schedule(schedule, now=false)
        handler = schedule.executor.new schedule.id, false
        scheduler_map = $_schedulers[Apartment::Tenant.current]
        s = scheduler_map[:scheduler]
        job_mapping = scheduler_map[:job_mapping]
        puts scheduler_map
        puts s
        puts job_mapping
        if now
          job_id = s.in '0s', handler
        else
          job_id = schedule.at ? s.at(schedule.at, handler) : s.cron(schedule.crontab, handler)
        end
        job = s.job job_id
        # Dynamically allow access to scheduler instance variable
        class << job
          attr_accessor :scheduler
        end
        # Store job id
        job_mapping[schedule.id] = job_id
      end
    end
  end
end