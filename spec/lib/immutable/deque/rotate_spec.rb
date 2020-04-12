require 'spec_helper'

describe Immutable::Deque do

  # Deques can have items distributed differently between the 'front' and 'rear' lists
  #   and still be equivalent
  # Since the implementation of #rotate depends on how items are distributed between the
  #   two lists, we need to test both the case where most items are on the 'front' and
  #   where most are on the 'rear'
  big_front = D.alloc(L.from_enum([1, 2, 3]), L.from_enum([5, 4]))
  big_rear  = D.alloc(L.from_enum([1, 2]), L.from_enum([5, 4, 3]))

  describe '#rotate' do
    [
      [[], 9999, []],
      [['A'], -1, ['A']],
      [['A', 'B', 'C'], -1, ['B', 'C', 'A']],
      [['A', 'B', 'C', 'D'], 0, ['A', 'B', 'C', 'D']],
      [%w[A B C D], 2, %w[C D A B]],
    ].each do |values, rotation, expected|
      context "on #{values.inspect}" do
        let(:deque) { D[*values] }

        it 'preserves the original' do
          deque.rotate(rotation)
          deque.should eql(D[*values])
        end

        it "returns #{expected.inspect}" do
          deque.rotate(rotation).should eql(D[*expected])
        end

        it 'returns a frozen instance' do
          deque.rotate(rotation).should be_frozen
        end
      end
    end

    context "on a Deque with most items on 'front' list" do
      it 'works with a small rotation' do
        big_front.rotate(2).should eql(D[4, 5, 1, 2, 3])
      end

      it 'works with a larger rotation' do
        big_front.rotate(4).should eql(D[2, 3, 4, 5, 1])
      end
    end

    context "on a Deque with most items on 'rear' list" do
      it 'works with a small rotation' do
        big_rear.rotate(2).should eql(D[4, 5, 1, 2, 3])
      end

      it 'works with a larger rotation' do
        big_rear.rotate(4).should eql(D[2, 3, 4, 5, 1])
      end
    end

    context 'on empty subclass' do
      let(:subclass) { Class.new(Immutable::Deque) }
      let(:empty_instance) { subclass.new }
      it 'returns an empty object of the same class' do
        empty_instance.rotate(1).class.should be subclass
        empty_instance.rotate(-1).class.should be subclass
      end
    end
  end
end
