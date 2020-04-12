require "spec_helper"

describe Immutable::Deque do
  describe "#inspect" do
    [
      [[], 'Immutable::Deque[]'],
      [["A"], 'Immutable::Deque["A"]'],
      [%w[A B C], 'Immutable::Deque["A", "B", "C"]']
    ].each do |values, expected|
      context "on #{values.inspect}" do
        let(:deque) { D[*values] }

        it "returns #{expected.inspect}" do
          deque.inspect.should == expected
        end

        it "returns a string which can be eval'd to get an equivalent object" do
          eval(deque.inspect).should eql(deque)
        end
      end
    end
  end
end
