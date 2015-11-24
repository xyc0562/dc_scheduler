class ScheduleExecutionGenerator < Rails::Generators::Base
  def create_initializer_file
    create_file 'app/models/schedule_execution.rb', <<EOF
class ScheduleExecution < DcScheduler::ScheduleExecution
end
EOF
  end
end