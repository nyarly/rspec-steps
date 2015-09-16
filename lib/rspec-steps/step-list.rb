require 'rspec-steps/step-result'

module RSpec::Steps
  class StepList
    include Enumerable

    def initialize
      @steps = []
      @let_bangs = []
      @let_blocks = {}
      @let_memos = Hash.new do |h,example|
        h[example] = Hash.new do |h, let_name|
          h[let_name] = example.instance_eval(&@let_blocks.fetch(let_name))
        end
      end
      @results = nil
    end
    attr_accessor :steps

    def add_let(name, block)
      @let_blocks[name] = block
    end

    # In this case, we scope the caching of a let block to an
    # example - which since the whole step list runs in a single example is
    # fine. It would be more correct to build a result-set and cache lets
    # there.
    def let_memo(name, example)
      @let_memos[example][name]
    end

    def add_let_bang(name)
      @let_bangs << name
    end

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
      @let_bangs.each do |let_name|
        context_example.__send__(let_name)
      end

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
