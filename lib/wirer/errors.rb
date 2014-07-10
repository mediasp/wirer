# coding: utf-8

module Wirer
  # Thank you to http://rubyforge.org/projects/nestegg for the pattern
  class Error < StandardError
    attr_reader :cause
    alias_method :wrapped_error, :cause

    def initialize(msg, cause = $ERROR_INFO)
      @cause = cause
      super(msg || cause && cause.message)
    end

    def set_backtrace(bt)
      if cause
        cause.backtrace.reverse.each do |line|
          bt.last == line ? bt.pop : break
        end
        bt << "cause: #{cause.class.name}: #{cause}"
        bt.concat cause.backtrace
      end
      super(bt)
    end
  end

  class DependencyFindingError < Error; end
  class CyclicDependencyError < Error; end

  # raised when a dependency could be found, but failed to be constructed.
  class DependencyConstructionError < Error; end
end
