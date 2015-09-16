module RSpec::Steps
  class Step < Struct.new(:metadata, :args, :action)
    def initialize(*whatever)
      super
      @failed_step = nil
    end
    attr_accessor :failed_step

    def define_on(step_list, example_group)
      step = self
      example_group.it(*args, metadata) do |example|
        step_list.run_only_once(self)
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
