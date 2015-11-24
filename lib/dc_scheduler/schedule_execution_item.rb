module DcScheduler
  module ScheduleExecutionItem
    def self.included(base)
      base.send :extend, ClassMethods
      base.send :include, InstanceMethods
    end

    module ClassMethods
      belongs_to :schedule_execution
      validates_presence_of :schedule_execution
      validates_presence_of :status
      validates_inclusion_of :status, allow_blank: true, in: [Constants::SCHEDULE_EXECUTION_FAILED,
                                                              Constants::SCHEDULE_EXECUTION_SUCCESSFUL]
      serialize :params, HashSerializer
      serialize :executions, ArrayHashSerializer
    end

    module InstanceMethods
    end
  end
end