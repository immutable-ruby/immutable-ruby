require "spec_helper"

describe Immutable::List do
  describe "#inspect" do
    context "on a really big list" do
      it "doesn't run out of stack" do
        -> { BigList.inspect }.should_not raise_error
      end
    end

    [
      [[], 'Immutable::List[]'],
      [["A"], 'Immutable::List["A"]'],
      [%w[A B C], 'Immutable::List["A", "B", "C"]']
    ].each do |values, expected|
      context "on #{values.inspect}" do
        let(:list) { L[*values] }

        it "returns #{expected.inspect}" do
          list.inspect.should == expected
        end

        it "returns a string which can be eval'd to get an equivalent object" do
          eval(list.inspect).should eql(list)
        end
      end
    end
  end
end