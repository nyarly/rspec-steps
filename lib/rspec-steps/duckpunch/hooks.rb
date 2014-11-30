require 'rspec/core/hooks'

module RSpec::Core::Hooks
  class HookCollections
    SCOPES << :step
  end
end
