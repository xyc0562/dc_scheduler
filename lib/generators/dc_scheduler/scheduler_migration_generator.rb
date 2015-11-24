module DcScheduler
  class SchedulerMigrationGenerator < Rails::Generators::Base
    def create_initializer_file
      ts = Time.now.strftime '%Y%m%d%H%M%S'
      create_file "db/migrate/#{ts}_dc_scheduler_create_tables.rb", <<EOF
class ScheduleExecution < DcScheduler::ScheduleExecution
  execute <<-SQL
  IF NOT EXISTS (SELECT 1 FROM pg_type WHERE typname = 'schedule_execution_status') THEN
    CREATE OR REPLACE TYPE schedule_execution_status AS ENUM
      ('INITIALIZING', 'INIT_FAILED', 'RUNNING', 'FAILED', 'PARTIALLY_SUCCESSFUL', 'SUCCESSFUL', 'CANCELED');
  END IF;
  SQL
  create_table :schedules do |t|
    t.string :name, unique: true, null: false
    t.text :description, null: true
    # Schedule should only be activated after `after` time
    # Note that this is especially important for activating
    # makeup schedule for recurring schedules
    t.datetime :after, null: false
    # Either scheduled once or recurring
    # At and crontab cannot co-exist but must have one
    t.datetime :at, null: true
    t.string :crontab, null: true
    # Inflection will be used to find the executor and pass it the data
    t.string :executor_name, index: true, null: false
    # If true, means its executor does not handle execution of each item, but instead delegate to some other
    # program (resque for example). This means log information is input by resque workers
    t.boolean :delegated, null: false
    # Arbitrary JSON data passed to the executor
    t.jsonb :data, null: true
    # Non-active schedules will not be executed
    t.boolean :active, null: false
    # If execution overdue and this flag is set to true
    # An execution will be conducted when server starts
    t.boolean :allow_makeup, null: false

    t.timestamps null: false
  end

  ##
  # Each recurrence of a particular schedule will be stored here
  create_table :schedule_executions do |t|
    t.column :status, :schedule_execution_status, null: false
    t.belongs_to :schedule, index: true, null: false
    # JSON data local to current execution
    # Note there is a difference between data column in schedules table
    # and this table. The former specifies requirements for each execution
    # schedule whereas this data stores every parameter needed to replay
    # current execution. In other words, if a particular schedule_execution
    # needs to be replayed (for example, previous execution failed), it could
    # be replayed by solely relying on executor_name (in parent schedule) and
    # data (in schedule_execution)
    t.jsonb :data, null: true
    t.boolean :makeup, null: false
    t.integer :item_count, null: false
    t.integer :successful_count, null: false
    t.integer :failed_count, null: false
    t.datetime :started_at, null: false
    t.datetime :finished_at, null: true
  end
  add_foreign_key :schedule_executions, :schedules, on_delete: :cascade, on_update: :cascade

  create_table :schedule_execution_items do |t|
    t.belongs_to :schedule_execution, index: true, null: false
    t.integer :idx, null: false, index: true
    # Params for replaying item
    t.column :status, :execution_result, null: true
    # Log for each item execution
    t.jsonb :executions, null: true
    t.timestamps null: false
  end
  add_foreign_key :schedule_execution_items, :schedule_executions, on_delete: :cascade, on_update: :cascade
  add_index :schedule_execution_items, [:schedule_execution_id, :idx], unique: true
end
EOF
    end
  end
end