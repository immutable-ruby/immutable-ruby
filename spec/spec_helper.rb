require "pry"
require "rspec"
require "immutable/hash"
require "immutable/set"
require "immutable/vector"
require "immutable/sorted_set"
require "immutable/list"
require "immutable/deque"
require "immutable/core_ext"
require "immutable/nested"

# Suppress warnings from use of old RSpec expectation and mock syntax
# If all tests are eventually updated to use the new syntax, this can be removed
RSpec.configure do |config|
  config.expect_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
  config.mock_with :rspec do |c|
    c.syntax = [:should, :expect]
  end
end

V  = Immutable::Vector
L  = Immutable::List
H  = Immutable::Hash
S  = Immutable::Set
SS = Immutable::SortedSet
D  = Immutable::Deque
EmptyList = Immutable::EmptyList

Struct.new("Customer", :name, :address)

def fixture(name)
  File.read(fixture_path(name))
end

def fixture_path(name)
  File.join("spec", "fixtures", name)
end

if RUBY_ENGINE == "ruby"
  def calculate_stack_overflow_depth(n)
    calculate_stack_overflow_depth(n + 1)
  rescue SystemStackError
    n
  end
  STACK_OVERFLOW_DEPTH = calculate_stack_overflow_depth(2)
else
  STACK_OVERFLOW_DEPTH = 16_384
end

BigList = Immutable.interval(0, STACK_OVERFLOW_DEPTH)

class DeterministicHash
  attr_reader :hash, :value

  def initialize(value, hash)
    @value = value
    @hash = hash
  end

  def to_s
    @value.to_s
  end

  def inspect
    @value.inspect
  end

  def ==(other)
    other.is_a?(DeterministicHash) && self.value == other.value
  end
  alias :eql? :==

  def <=>(other)
    self.value <=> other.value
  end
end

class EqualNotEql
  def ==(other)
    true
  end
  def eql?(other)
    false
  end
end

class EqlNotEqual
  def ==(other)
    false
  end
  def eql?(other)
    true
  end
end
