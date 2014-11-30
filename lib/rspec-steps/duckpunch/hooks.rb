require 'rspec/core/hooks'

module RSpec::Core::Hooks
  class HookCollections
    SCOPES << :step

    def initialize(owner, data)
      @owner = owner
      @data = data.merge(
        :before => data[:before].merge(:step => HookCollection.new),
        :after  => data[:after ].merge(:step => HookCollection.new)
      )
    end
  end
end
