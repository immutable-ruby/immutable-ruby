require 'spec_helper'

describe Immutable::Vector do
  describe '#to_set' do
    [
      [],
      ['A'],
      %w[A B C],
      (1..10),
      (1..32),
      (1..33),
      (1..1000)
    ].each do |values|
      describe "on #{values.inspect}" do
        it 'returns a set with the same values' do
          V[*values].to_set.should eql(S[*values])
        end
      end
    end
  end
end
