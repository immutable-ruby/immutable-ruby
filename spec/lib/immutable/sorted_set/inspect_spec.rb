require 'spec_helper'

describe Immutable::SortedSet do
  describe '#inspect' do
    [
      [[], 'Immutable::SortedSet[]'],
      [['A'], 'Immutable::SortedSet["A"]'],
      [['C', 'B', 'A'], 'Immutable::SortedSet["A", "B", "C"]']
    ].each do |values, expected|
      context "on #{values.inspect}" do
        let(:sorted_set) { SS[*values] }

        it "returns #{expected.inspect}" do
          sorted_set.inspect.should == expected
        end

        it "returns a string which can be eval'd to get an equivalent set" do
          eval(sorted_set.inspect).should eql(sorted_set)
        end
      end
    end

    MySortedSet = Class.new(Immutable::SortedSet)

    context 'from a subclass' do
      let(:sorted_set) { MySortedSet[1, 2] }

      it 'returns a programmer-readable representation of the set contents' do
        sorted_set.inspect.should == 'MySortedSet[1, 2]'
      end

      it "returns a string which can be eval'd to get an equivalent set" do
        eval(sorted_set.inspect).should eql(sorted_set)
      end
    end
  end
end
