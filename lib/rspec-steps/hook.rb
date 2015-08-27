require 'rspec-steps/dsl'

module RSpec::Steps
  class Hook < Struct.new(:type, :kind, :action)
    def rspec_kind
      case kind
      when :each
        warn_about_promotion(type)
        :all
      when :step
        :each
      else
        kind
      end
    end

    def warn_about_promotion(scope_name)
      RSpec::Steps.warnings[
        "#{scope_name} :each blocks declared for steps are always treated as " +
        ":all scope (it's possible you want #{scope_name} :step)"]
    end

    def define_on(example_group)
      case type
      when :before
        example_group.before rspec_kind, &action
      when :after
        example_group.after rspec_kind, &action
      when :around
        example_group.around rspec_kind, &action
      end
    end
  end
end
