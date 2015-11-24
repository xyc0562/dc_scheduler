module DcScheduler
  class ScheduleExecution < ActiveRecord::Base
    def redo_item(params)
      idx = params[:idx]
      # Always get item's last execution's parameters
      # in the future, we may want to consider overriding parameters as well
      args = items.find_by(idx: idx).executions[-1]['params']
      # Queue up
      Resque.enqueue *([args[0].constantize, args[1..-1]].flatten)
    end

    belongs_to :schedule
    validates_presence_of :schedule
    validates_presence_of :status
    validates_inclusion_of :status, allow_blank: true, in: [Constants::SCHEDULE_EXECUTION_INITIALIZING,
                                                            Constants::SCHEDULE_EXECUTION_INIT_FAILED,
                                                            Constants::SCHEDULE_EXECUTION_RUNNING,
                                                            Constants::SCHEDULE_EXECUTION_FAILED,
                                                            Constants::SCHEDULE_EXECUTION_SUCCESSFUL,
                                                            Constants::SCHEDULE_EXECUTION_PARTIALLY_SUCCESSFUL,
                                                            Constants::SCHEDULE_EXECUTION_CANCELED]
    validates_inclusion_of :makeup, in: [true, false]
    validates_presence_of :started_at
    has_many :items, class_name: 'ScheduleExecutionItem', dependent: :destroy
    serialize :data, HashSerializer
    serialize :items, HashSerializer
  end
end
