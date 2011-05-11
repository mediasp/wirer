module Wirer
  class Error < StandardError; end
  class DependencyFindingError < Error; end
  class CyclicDependencyError < Error; end

  # raised when a dependency could be found, but failed to be constructed.
  class DependencyConstructionError < Error
    attr_reader :wrapped_error
    def initialize(msg, wrapped_error=nil)
      @wrapped_error = wrapped_error
      super(msg)
    end
  end
end
