module Wirer
  module Factory; end

  # This is the basic Factory interface around which the whole framework is built.
  #
  # You won't normally need to implement this interface yourself, but it's useful
  # in terms of understanding how Wirer works.
  #
  # A Factory is responsible for creating some kind of object, given some dependencies
  # and possibly some additional arguments. so new_from_dependencies is the main
  # method here.
  #
  # It also comes with an interface (constructor_dependencies) telling you what
  # the required dependencies are; this is specified via a hash of symbol argument
  # names to Dependency objects which specify the criterea that must be satisfied
  # for the dependency argument of that name.
  #
  # Wirer::Container uses this metadata to find and pass in dependencies automatically
  # when constructing things from Factories.
  #
  # == Two-phase initialisation
  #
  # Factory can also support cases where some dependencies need to be passed in
  # after creation time, eg when you have cyclic dependencies.
  #
  # This is done via specifying setter_dependencies in the same way as
  # constructor_dependencies; the expectation is that after constructing an instance
  # with new_from_dependencies, you must additionally fetch any setter_dependencies
  # and 'inject' them into the instance via calling inject_dependency on the factory
  # with the instance, dependency name and the value for that dependency.
  #
  # (the default implementation of inject_dependency will just call a setter method
  #  on the instance, eg instance.logger = logger; this will work with a private setter
  #  if you prefer to make private these things which are only a part of initialization)
  #
  # After a whole set of objects have been created and their setter_dependencies injected, it
  # can be handy for them to get a notification along the lines of "hey so your whole dependency
  # graph is now all wired up any ready". Factory#post_initialize should send this notification
  # to an object created from the factory, where it's supported by the objects you construct.
  #
  # (by default it will call a :post_initialize method on the instance, if this is present;
  #  again this can be a private method if you wish).
  module Factory::Interface
    # A Module or Class which all objects constructed by this factory are kind_of?.
    # The more specific you are, the more use this will be when specifying requirements
    # based on a Module or Class.
    def provides_class
      Object # not very informative by default :)
    end

    # List of arbitrary objects representing features provided by this factory,
    # which may be compared against required features when looking for dependencies.
    # Typically symbols are used.
    def provides_features
      []
    end

    # Hash of symbol argument names to Wirer::Dependency objects, representing
    # dependencies that need to be passed as arguments to new_from_dependencies
    def constructor_dependencies
      {}
    end

    # Hash of symbol argument names to Wirer::Dependency objects, representing
    # dependencies which need to be injected into instances *after* they have
    # been constructed via new_from_dependencies
    #
    # if no instance is passed, should return a hash of any setter dependencies
    # applying to all instances constructed from this factory. (which may be none)
    #
    # if an instance is passed, it may add to this hash any additional setter dependencies
    # which are specific to this instance. This is useful when you have some extra set
    # of dependencies which varies depending on the parameters to the constructor.
    def setter_dependencies(instance=nil)
      {}
    end

    # Will be passed a hash which has keys for all of the argument names specified
    # in constructor_dependencies, together with values which are the constructed
    # dependencies meeting the requirements of the corresponding Wirer::Depedency.
    #
    # May also be passed additional non-dependency arguments supplied directly
    # to the factory.
    #
    # The following must hold:
    #   factory.new_from_dependencies(dependencies, ...).is_a?(factory.provides_class)
    #
    # however the following is not required to hold:
    #   factory.new_from_dependencies(dependencies, ...).instance_of?(factory.provides_class)
    def new_from_dependencies(dependencies={}, *other_args, &block_arg)
      raise NotImplementedError
    end

    def inject_dependency(instance, attr_name, dependency)
      instance.send(:"#{attr_name}=", dependency)
    end

    def post_initialize(instance)
      instance.send(:post_initialize) if instance.respond_to?(:post_initialize, true)
    end

    def wrapped_with(additional_options={}, &wrapped_constructor_block)
      Factory::Wrapped.new(self, additional_options, &wrapped_constructor_block)
    end
  end

end
