require 'spec_helper'

describe Immutable::Hash do
  let(:hash) { H['A' => 'aye', 'B' => 'bee', 'C' => 'see'] }

  [:dup, :clone].each do |method|
    describe "##{method}" do
      it 'returns self' do
        hash.send(method).should equal(hash)
      end
    end
  end
end
