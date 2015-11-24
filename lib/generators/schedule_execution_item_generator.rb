class ScheduleExecutionItemGenerator < Rails::Generators::Base
  def create_initializer_file
    create_file 'app/models/schedule_execution_item.rb', <<EOF
class ScheduleExecutionItem < DcScheduler::ScheduleExecutionItem
end
EOF
  end
end