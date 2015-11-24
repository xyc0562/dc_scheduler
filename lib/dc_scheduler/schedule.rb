module DcScheduler
  module Schedule
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      ##
      # @return [Schedule]
      def all_active_schedules
        where(active: true).all
      end

      has_many :executions, class_name: ScheduleExecution, dependent: :destroy
      validates_presence_of :executor_name
      validates_inclusion_of :active, in: [true, false]
      validates_inclusion_of :allow_makeup, in: [true, false]
      validates_presence_of :after
      validate :validate_time
      validate :validate_executor
      serialize :data, HashSerializer
      before_validation do
        self.delegated = false if delegated.nil?
      end
    end

    module InstanceMethods
      def last_execution_at
        exe = ScheduleExecution.where(schedule_id: id).order(started_at: :desc).first
        exe ? exe.started_at : nil
      end

      ##
      # For one time schedules, trigger point must be in the past
      # Otherwise nil is returned
      def last_trigger_at
        if at
          at.to_i < Time.now.to_i ? at : nil
        else
          @parser = CronParser.new(crontab) unless @parser
          @parser.last
        end
      end

      ##
      # For one time schedules, trigger point must be in the future
      # Otherwise nil is returned
      def next_trigger_at
        if at
          at.to_i > Time.now.to_i ? at : nil
        else
          @parser = CronParser.new(crontab) unless @parser
          @parser.next
        end
      end

      ##
      # Get executor class
      def executor
        executor_name.classify.constantize
      end

      ##
      # Crontab and at
      def validate_time
        if crontab.blank? && !at
          errors[:crontab]  = 'Either `crontab` or `at` must exist for a valid schedule.'
        elsif !crontab.blank? && at
          errors[:crontab]  = '`crontab` or `at` cannot both exist.'
        elsif !crontab.blank? && !Utils.valid_crontab?(crontab)
          errors[:crontab]  = "crontab expression `#{crontab}` is invalid."
        end
      end

      ##
      # Make sure a executor is valid
      def validate_executor
        executor rescue errors[:executor_name] = "Schedule executor #{executor_name} is not found."
      end
    end

  end
end