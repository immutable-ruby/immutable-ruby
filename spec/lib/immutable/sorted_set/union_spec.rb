require "spec_helper"

describe Immutable::SortedSet do
  [:union, :|, :+, :merge].each do |method|
    describe "##{method}" do
      [
        [[], [], []],
        [["A"], [], ["A"]],
        [["A"], ["A"], ["A"]],
        [%w[A B C], [], %w[A B C]],
        [%w[A C E G X], %w[B C D E H M], %w[A B C D E G H M X]]
      ].each do |a, b, expected|
        context "for #{a.inspect} and #{b.inspect}" do
          it "returns #{expected.inspect}" do
            SS[*a].send(method, SS[*b]).should eql(SS[*expected])
          end
        end

        context "for #{b.inspect} and #{a.inspect}" do
          it "returns #{expected.inspect}" do
            SS[*b].send(method, SS[*a]).should eql(SS[*expected])
          end
        end
      end

      it "filters out duplicates when passed an Array" do
        sorted_set = SS['A', 'B', 'C', 'D'].union(['A', 'A', 'A', 'C', 'A', 'B', 'E'])
        expect(sorted_set.to_a).to eq(['A', 'B', 'C', 'D', 'E'])
      end
    end
  end
end