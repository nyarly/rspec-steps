module RSpec::Steps
  class Builder
    def initialize(describer)
      @describer = describer
    end

    def build_example_group
      describer = @describer

      RSpec.describe(*describer.group_args, describer.metadata) do
        describer.let_list.each do |letter|
          letter.define_on(describer.step_list, self)
        end
        describer.hooks.each do |hook|
          hook.define_on(self)
        end
        describer.step_list.each do |step|
          step.define_on(describer.step_list, self)
        end
      end
    end
  end
end
