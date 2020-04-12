require 'spec_helper'
require 'immutable/vector'

describe Immutable::Vector do
  let(:v) { V[1, 2, V[3, 4]] }

  describe '#dig' do
    it 'returns value at the index with one argument' do
      expect(v.dig(0)).to eq(1)
    end

    it 'returns value at index in nested arrays' do
      expect(v.dig(2, 0)).to eq(3)
    end

    # This is different from Hash#dig, but it matches the behavior of Ruby's
    #   built-in Array#dig (except that Array#dig raises a TypeError)
    it 'raises an error when indexing deeper than possible' do
      expect { (v.dig(0, 0)) }.to raise_error(NoMethodError)
    end

    it 'returns nil if you index past the end of an array' do
      expect(v.dig(5)).to eq(nil)
    end

    it "raises an error when indexing with a key vectors don't understand" do
      expect { v.dig(:foo) }.to raise_error(ArgumentError)
    end
  end
end
