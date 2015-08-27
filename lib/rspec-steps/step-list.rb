require 'rspec-steps/step-result'

module RSpec::Steps
  class StepList
    include Enumerable

    def initialize
      @steps = []
      @results = nil
    end
    attr_accessor :steps

    def add(step)
      @steps << step
    end
    alias << add

    def +(other)
      result = StepList.new
      result.steps = steps + other.steps
      result
    end

    def each(&block)
      @steps.each(&block)
    end

    def result_for(step)
      @results[step]
    end

    def run_only_once(context_example)
      return unless @results.nil?
      failed_step = nil
      @results = Hash[ @steps.map do |step|
        [
          step,
          if failed_step.nil?
            result = capture_result(step, context_example)
            if result.failed?
              failed_step = result
            end
            result
          else
            StepResult.new(step, nil, nil, failed_step)
          end
        ]
      end ]
    end

    def capture_result(step, context_example)
      StepResult.new(step, step.run_inside(context_example), nil, nil)
    rescue BasicObject => ex
      StepResult.new(step, nil, ex, nil)
    end
  end
end
