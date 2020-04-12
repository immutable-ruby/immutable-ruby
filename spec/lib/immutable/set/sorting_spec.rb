require 'spec_helper'

describe Immutable::Set do
  [
    [:sort, ->(left, right) { left.length <=> right.length }],
    [:sort_by, ->(item) { item.length }],
  ].each do |method, comparator|
    describe "##{method}" do
      [
        [[], []],
        [['A'], ['A']],
        [%w[Ichi Ni San], %w[Ni San Ichi]],
      ].each do |values, expected|
        describe "on #{values.inspect}" do
          let(:set) { S[*values] }

          describe 'with a block' do
            let(:result) { set.send(method, &comparator) }

            it "returns #{expected.inspect}" do
              result.should eql(SS.new(expected, &comparator))
              result.to_a.should == expected
            end

            it "doesn't change the original Set" do
              result
              set.should eql(S.new(values))
            end
          end

          describe 'without a block' do
            let(:result) { set.send(method) }

            it "returns #{expected.sort.inspect}" do
              result.should eql(SS[*expected])
              result.to_a.should == expected.sort
            end

            it "doesn't change the original Set" do
              result
              set.should eql(S.new(values))
            end
          end
        end
      end
    end
  end

  describe '#sort_by' do
    # originally this test checked that #sort_by only called the block once
    #   for each item
    # however, when initializing a SortedSet, we need to make sure that it
    #   does not include any duplicates, and we use the block when checking that
    # the real point here is that the block should not be called an excessive
    #   number of times, degrading performance
    it 'calls the passed block no more than twice for each item' do
      count = 0
      fn    = lambda { |x| count += 1; -x }
      items = 100.times.collect { rand(10000) }.uniq

      S[*items].sort_by(&fn).to_a.should == items.sort.reverse
      count.should <= (items.length * 2)
    end
  end
end
