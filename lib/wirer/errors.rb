module Wirer
  class Error < StandardError; end
  class DependencyFindingError < Error; end
  class CyclicDependencyError < Error; end
end
