require "spec_helper"
require "pp"
require "stringio"

describe Immutable::Deque do
  describe "#pretty_print" do
    let(:deque) { Immutable::Deque["AAAA", "BBBB", "CCCC"] }
    let(:stringio) { StringIO.new }

    it "prints the whole Deque on one line if it fits" do
      PP.pp(deque, stringio, 80)
      stringio.string.chomp.should == 'Immutable::Deque["AAAA", "BBBB", "CCCC"]'
    end

    it "prints each item on its own line, if not" do
      PP.pp(deque, stringio, 10)
      stringio.string.chomp.should == 'Immutable::Deque[
 "AAAA",
 "BBBB",
 "CCCC"]'
    end
  end
end
