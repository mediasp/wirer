module Wirer
  # For when you have some pre-existing instance which you want to wrap as a singleton
  # Factory.
  # (You wouldn't normally need to do this yourself, but rather Container uses it
  #  under the hood if you add an existing instance to the container)
  class Factory::FromInstance
    include Factory::Interface

    attr_reader :instance, :provides_features

    def initialize(instance, *features)
      @instance = instance
      @provides_features = features
    end

    def provides_class
      @instance.class
    end

    def new_from_dependencies(deps=nil)
      @instance
    end
  end
end
