require 'spec_helper'

describe Immutable::List do
  describe '#zip' do
    it 'is lazy' do
      -> { Immutable.stream { fail }.zip(Immutable.stream { fail }) }.should_not raise_error
    end

    [
      [[], [], []],
      [['A'], ['aye'], [L['A', 'aye']]],
      [['A'], [], [L['A', nil]]],
      [[], ['A'], [L[nil, 'A']]],
      [%w[A B C], %w[aye bee see], [L['A', 'aye'], L['B', 'bee'], L['C', 'see']]],
    ].each do |left, right, expected|
      context "on #{left.inspect} and #{right.inspect}" do
        it "returns #{expected.inspect}" do
          L[*left].zip(L[*right]).should eql(L[*expected])
        end
      end
    end
  end
end
