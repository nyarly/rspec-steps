require 'rspec-steps'
require 'rspec-sandbox'

describe RSpec::Core::ExampleGroup do
  describe "::steps" do
    it "should create an ExampleGroup that includes RSpec::Stepwise" do
      group = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
        end
      end
      expect((class << group; self; end).included_modules).to include(RSpecStepwise::ClassMethods)
    end
  end

  describe "with Stepwise included" do
    it "should retain instance variables between steps" do
      group = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          it("sets @a"){ @a = 1 }
          it("reads @a"){ @a.should == 1}
        end
        group.run
      end

      group.examples.each do |example|
        expect(example.metadata[:execution_result].status).to eq(:passed)
      end
    end

    it "should work with shared_steps/perform steps" do
      group = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          shared_steps "add one" do
            it("adds one to @a"){ @a += 1 }
          end
          it("sets @a"){ @a = 1 }
          perform_steps "add one"
          perform_steps "add one"
          perform_steps "add one"
          it("reads @a"){ @a.should == 4 }
        end
        group.run
      end

      expect(group.examples.length).to eq(5)

      group.examples.each do |example|
        expect(example.metadata[:execution_result].status).to eq(:passed)
      end
    end

    it "should run each_step hooks" do
      group = nil
      afters = []
      befores = []

      sandboxed do
        group = RSpec.steps "Test Each Step" do
          before :each  do
            befores << :each
          end
          after :each do
            afters << :each
          end

          before :all  do
            befores << :all
          end
          after :all do
            afters << :all
          end

          before :step  do
            befores << :step
          end
          after :step do
            afters << :step
          end

          it "should 1" do
            1.should == 1
          end
          it "should 2" do
            2.should == 2
          end
          it "should 3" do
            3.should == 3
          end
        end
        group.run
      end

      expect(befores.find_all{|item| item == :all}.length).to eq(1)
      expect(befores.find_all{|item| item == :each}.length).to eq(1)
      expect(befores.find_all{|item| item == :step}.length).to eq(3)
      expect(afters.find_all{|item| item == :all}.length).to eq(1)
      expect(afters.find_all{|item| item == :each}.length).to eq(1)
      expect(afters.find_all{|item| item == :step}.length).to eq(3)
    end

    it "should mark later examples as failed if a before hook fails" do
      group = nil
      exception = Exception.new "Testing Error"

      result = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          before { raise exception }
          it { 1.should == 1 }
          it { 1.should == 1 }
        end
        result = group.run
      end

      expect(result).to eq(false)
    end

    it "should mark later examples as pending if one fails" do
      group = nil
      result = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          it { fail "All others fail" }
          it { 1.should == 1 }
        end
        result = group.run
      end

      expect(result).to eq(false)
      expect(group.examples[0].metadata[:execution_result].status).to eq(:failed)
      expect(group.examples[1].metadata[:execution_result].status).to eq(:pending)
    end

    it "should allow nested steps", :pending => "Not really" do
      group = nil
      sandboxed do
        group = RSpec.steps "Test Steps" do
          steps "Nested" do
            it { @a = 1 }
            it { @a.should == 1}
          end
        end
        group.run
      end

      group.children[0].examples.each do |example|
        expect(example.metadata[:execution_result].status).to eq(:passed)
      end
      expect(group.children[0].size).to eq(2)
    end

    it "should not allow nested normal contexts" do
      pending "A correct approach - in the meantime, this behavior is undefined"
      expect {
        sandboxed do
        RSpec.steps "Basic" do
          describe "Not allowed" do
          end
        end
        end
      }.to raise_error
    end
  end
end
