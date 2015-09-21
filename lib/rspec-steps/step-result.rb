module RSpec::Steps
  class StepResult < Struct.new(:step, :result, :exception, :failed_step)
    def failed?
      return (!exception.nil?)
    end

    def has_executed_successfully?
      if failed_step.nil?
        if exception.nil?
          true
        else
          raise exception
        end
      else
        raise failed_step.exception
      end
    end

    def is_after_failed_step?
      !!failed_step
    end
  end
end
