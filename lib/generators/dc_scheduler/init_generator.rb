module DcScheduler
  class InitGenerator < Rails::Generators::Base
    def run_other_generators
      generate 'dc_scheduler::scheduler_migration'
      generate 'dc_scheduler::schedule'
      generate 'dc_scheduler::schedule_execution'
      generate 'dc_scheduler::schedule_execution_item'
    end
  end
end