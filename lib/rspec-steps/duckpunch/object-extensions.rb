require 'rspec-steps/duckpunch/example-group'
require 'rspec-steps/stepwise'

module RSpec::Steps
  module ObjectExtensions
    alias :shared_steps :shared_context
    alias :steps_shared_as :share_as
  end
end

include RSpec::Steps::ObjectExtensions
extend RSpec::Steps::ClassMethods
