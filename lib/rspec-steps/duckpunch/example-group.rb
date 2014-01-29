require 'rspec/core'
require 'rspec-steps/stepwise'

module RSpec::Steps
  module DSL
    def steps(*args, &block)
      options =
        if args.last.is_a?(Hash)
          args.pop
        else
          {}
        end
      options[:stepwise] = true
      options[:caller] ||= caller
      args.push(options)

      describe(*args, &block)
    end
  end
end

RSpec::Core::ExampleGroup.extend RSpec::Steps::DSL

extend RSpec::Steps::DSL
Module::send(:include, RSpec::Steps::DSL)

RSpec::configuration.include(RSpecStepwise, :stepwise => true)
