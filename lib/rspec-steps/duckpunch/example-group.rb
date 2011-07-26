require 'rspec-steps/stepwise'

module RSpec::Core
  class ExampleGroup
    def self.steps(*args, &example_group_block)
      describe(*args) do
        extend RSpecStepwise
        module_eval &example_group_block
      end
    end
  end
end
