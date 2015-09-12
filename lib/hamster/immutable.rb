module Hamster
  # @private
  module Immutable
    def self.included(klass)
      klass.extend(ClassMethods)
      klass.instance_eval do
        include InstanceMethods
      end
    end

    # @private
    module ClassMethods
      def new(*args)
        super.__send__(:immutable!)
      end
    end

    # @private
    module InstanceMethods
      def immutable!
        freeze
      end

      def immutable?
        frozen?
      end

      def dup
        self
      end

      def clone
        self
      end
    end
  end
end
