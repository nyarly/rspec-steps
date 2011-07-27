require 'rspec-steps/stepwise'

module RSpec::Steps
  module ClassMethods
    def steps(*args, &block)
      options = if args.last.is_a?(Hash) then args.pop else {} end
      options[:stepwise] = true
      options[:caller] ||= caller
      args.push(options)

      describe(*args, &block)
    end
  end
end

RSpec::Core::ExampleGroup.extend RSpec::Steps::ClassMethods

RSpec::configuration.include(RSpecStepwise, :stepwise => true)
