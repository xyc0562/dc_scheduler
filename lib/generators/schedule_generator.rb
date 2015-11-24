class ScheduleGenerator < Rails::Generators::Base
  def create_initializer_file
    create_file 'app/models/schedule.rb', <<EOF
class Schedule < ActiveRecord::Base
  include DcScheduler::Schedule
end
EOF
  end
end