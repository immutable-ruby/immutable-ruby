# Definition of Immutable::Hash is in a separate file to avoid circular
# dependency warnings caused by dependencies between Hash ↔ Vector and
# Hash ↔ Set
require 'immutable/_core'
