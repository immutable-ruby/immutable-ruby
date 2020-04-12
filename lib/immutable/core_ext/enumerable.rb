require 'immutable/list'

# Monkey-patches to Ruby's built-in `Enumerable` module.
# @see http://www.ruby-doc.org/core/Enumerable.html
module Enumerable
  # Return a new {Immutable::List} populated with the items in this `Enumerable` object.
  # @return [List]
  def to_list
    Immutable::List.from_enum(self)
  end
end
