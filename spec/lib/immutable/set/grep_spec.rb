require 'spec_helper'

describe Immutable::Set do
  let(:set) { S[*values] }

  describe '#grep' do
    let(:grep) { set.grep(String, &block) }

    shared_examples 'check filtered values' do
      it 'returns the filtered values' do
        expect(grep).to eq(S[*filtered])
      end
    end

    shared_examples 'check different types of inputs' do
      context 'with an empty set' do
        let(:values) { [] }
        let(:filtered) { [] }

        include_examples 'check filtered values'
      end

      context 'with a single item set' do
        let(:values) { ['A'] }
        let(:filtered) { ['A'] }

        include_examples 'check filtered values'
      end

      context "with a single item set that doesn't contain match" do
        let(:values) { [1] }
        let(:filtered) { [] }

        include_examples 'check filtered values'
      end

      context "with a multi-item set where one isn't a match" do
        let(:values) { ['A', 2, 'C'] }
        let(:filtered) { %w[A C] }

        include_examples 'check filtered values'
      end
    end

    context 'without a block' do
      let(:block) { nil }

      include_examples 'check different types of inputs'
    end

    describe 'with a block' do
      let(:block) { ->(item) { item }}

      include_examples 'check different types of inputs'
    end
  end
end
