module RSpec::Steps
  class Step
    def initialize(*args, &action)
      @args = args
      @action = action
      @failed_step = nil
    end
    attr_reader  :args, :action
    attr_accessor :failed_step

    def define_on(step_list, example_group)
      step = self
      example_group.it(*args) do |in_context|
        step_list.run_only_once(in_context)
        result = step_list.result_for(step)
        pending if result.is_after_failed_step?
        expect(result).to have_executed_successfully
      end
    end

    def run_inside(example)
      example.instance_eval(&action)
    end

  end
end
