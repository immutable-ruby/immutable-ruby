require "spec_helper"

describe Immutable::Deque do
  describe "#rotate" do
    [
      [[], 9999, []],
      [['A'], -1, ['A']],
      [['A', 'B', 'C'], -1, ['B', 'C', 'A']],
      [['A', 'B', 'C', 'D'], 0, ['A', 'B', 'C', 'D']],
      [%w[A B C D], 2, %w[C D A B]],
    ].each do |values, rotation, expected|
      context "on #{values.inspect}" do
        let(:deque) { D[*values] }

        it "preserves the original" do
          deque.rotate(rotation)
          deque.should eql(D[*values])
        end

        it "returns #{expected.inspect}" do
          deque.rotate(rotation).should eql(D[*expected])
        end

        it "returns a frozen instance" do
          deque.rotate(rotation).should be_frozen
        end
      end
    end

    context "on empty subclass" do
      let(:subclass) { Class.new(Immutable::Deque) }
      let(:empty_instance) { subclass.new }
      it "returns an empty object of the same class" do
        empty_instance.rotate(1).class.should be subclass
        empty_instance.rotate(-1).class.should be subclass
      end
    end
  end
end
