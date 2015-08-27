module RSpec::Steps
  class Builder
    def initialize(describer)
      @describer = describer
    end
    attr_reader :describer

    def build_example_group
      step_list = describer.step_list
      hook_list = describer.hooks
      RSpec.describe(*describer.group_args) do
        hook_list.each do |hook|
          hook.define_on(self)
        end
        step_list.each do |step|
          step.define_on(step_list, self)
        end
      end
    end
  end
end
