module DcScheduler
  class ProxiedJob
    class << self
      def perform(tenant, schedule_execution_id, idx, *args)
        begin
          execution_log = {
              meta: {
                  # Params used for possible re-execution of job in the future
                  params: [name, tenant, schedule_execution_id, idx, *args],
                  started_at: Time.now
              }
          }
          meta = execution_log[:meta]
          Rails.logger.debug "Running #{name} for tenant: #{tenant} with index: #{idx} with parameters: #{args}"
          # Switch to specific tenant
          Apartment::Tenant.switch tenant do
            status = Constants::SCHEDULE_EXECUTION_FAILED
            begin
              status = Constants::SCHEDULE_EXECUTION_SUCCESSFUL if perform_concrete execution_log, *args
            rescue
              Rollbar.error $!
              Rails.logger.error $!
              meta[:exception] = "#{$!.message}\n#{$!.backtrace.join '\n'}"
            ensure
              meta[:finished_at] = Time.now
              ActiveRecord::Base.transaction do
                se = ScheduleExecution.find schedule_execution_id
                item = ScheduleExecutionItem.find_by schedule_execution_id: schedule_execution_id, idx: idx
                item ||= se.items.new idx: idx
                meta[:status] = status
                item.status = status
                item.executions ||= []
                if item.executions.present?
                  last_execution = item.executions[-1]
                else
                  last_execution = nil
                end
                # If previous execution exists
                successful = status == Constants::SCHEDULE_EXECUTION_SUCCESSFUL
                if last_execution
                  prev_successful = last_execution[:status] == Constants::SCHEDULE_EXECUTION_SUCCESSFUL
                  if prev_successful && !successful
                    se.failed_count += 1
                    se.successful_count -= 1
                  elsif !prev_successful && successful
                    se.successful_count += 1
                    se.failed_count -= 1
                  end
                else
                  # If no previous execution exists
                  if successful
                    se.successful_count += 1
                  else
                    se.failed_count += 1
                  end
                end
                # Either way, save the item log
                item.executions << execution_log
                item.save!
                # Update status of schedule_execution
                if se.successful_count + se.failed_count == se.item_count
                  if se.failed_count == 0
                    se.status = Constants::SCHEDULE_EXECUTION_SUCCESSFUL
                  elsif se.successful_count == 0
                    se.status = Constants::SCHEDULE_EXECUTION_FAILED
                  else
                    se.status = Constants::SCHEDULE_EXECUTION_PARTIALLY_SUCCESSFUL
                  end
                  se.finished_at = Time.now
                end
                se.save!
              end
            end
          end
        rescue
          Rollbar.error $!
          Rails.logger.error $!
        end
      end

      # To be overridden by subclass
      def perform_concrete(execution_log, *args)
      end
    end
  end
end