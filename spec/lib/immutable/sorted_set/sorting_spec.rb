require "spec_helper"

describe Immutable::SortedSet do
  [
    [:sort, ->(left, right) { left.length <=> right.length }],
    [:sort_by, ->(item) { item.length }],
  ].each do |method, comparator|
    describe "##{method}" do
      [
        [[], []],
        [["A"], ["A"]],
        [%w[Ichi Ni San], %w[Ni San Ichi]],
      ].each do |values, expected|
        describe "on #{values.inspect}" do
          let(:sorted_set) { SS.new(values) { |item| item.reverse }}

          context "with a block" do
            it "preserves the original" do
              sorted_set.send(method, &comparator)
              sorted_set.to_a.should == SS.new(values) { |item| item.reverse }
            end

            it "returns #{expected.inspect}" do
              sorted_set.send(method, &comparator).class.should be(Immutable::SortedSet)
              sorted_set.send(method, &comparator).to_a.should == expected
            end
          end

          context "without a block" do
            it "preserves the original" do
              sorted_set.send(method)
              sorted_set.to_a.should == SS.new(values) { |item| item.reverse }
            end

            it "returns #{expected.sort.inspect}" do
              sorted_set.send(method).class.should be(Immutable::SortedSet)
              sorted_set.send(method).to_a.should == expected.sort
            end
          end
        end
      end
    end
  end

  describe :sort do
    context "on a SortedSet with custom sort order" do
      let(:sorted_set) { SS.new([1,2,3,4]) { |x,y| y <=> x }}

      it "returns a SortedSet with the natural sort order" do
        result = sorted_set.sort
        expect(sorted_set.to_a).to eq([4,3,2,1])
        expect(result.to_a).to eq([1,2,3,4])
      end
    end
  end
end
