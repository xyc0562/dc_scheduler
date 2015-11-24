module DcScheduler
  class ScheduleGenerator < Rails::Generators::Base
    def create_initializer_file
      create_file 'app/models/schedule.rb', <<EOF
class Schedule < DcScheduler::Schedule
end
EOF
    end
  end
end