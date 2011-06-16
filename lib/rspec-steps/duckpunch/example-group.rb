require 'rspec-steps/stepwise'

module RSpec::Core
  class ExampleGroup
    def self.steps(*args, &example_group_block)
      group = describe(*args, &example_group_block)
      group.extend RSpecStepwise
      group
    end
  end
end
