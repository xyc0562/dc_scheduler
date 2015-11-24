module DcScheduler
  class ScheduleExecutionItem < ActiveRecord::Base
    belongs_to :schedule_execution
    validates_presence_of :schedule_execution
    validates_presence_of :status
    validates_inclusion_of :status, allow_blank: true, in: [Constants::SCHEDULE_EXECUTION_FAILED,
                                                            Constants::SCHEDULE_EXECUTION_SUCCESSFUL]
    serialize :params, HashSerializer
    serialize :executions, ArrayHashSerializer
  end
end