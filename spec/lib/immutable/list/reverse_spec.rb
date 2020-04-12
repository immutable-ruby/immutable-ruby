require 'spec_helper'

describe Immutable::List do
  describe '#reverse' do
    context 'on a really big list' do
      it "doesn't run out of stack" do
        -> { BigList.reverse }.should_not raise_error
      end
    end

    it 'is lazy' do
      -> { Immutable.stream { fail }.reverse }.should_not raise_error
    end

    [
      [[], []],
      [['A'], ['A']],
      [%w[A B C], %w[C B A]],
    ].each do |values, expected|
      context "on #{values.inspect}" do
        let(:list) { L[*values] }

        it 'preserves the original' do
          list.reverse { |item| item.downcase }
          list.should eql(L[*values])
        end

        it "returns #{expected.inspect}" do
          list.reverse { |item| item.downcase }.should == L[*expected]
        end
      end
    end
  end
end
