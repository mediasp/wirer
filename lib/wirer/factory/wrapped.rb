module Wirer
  # Allows an existing Factory to be wrapped with extra options for a specific context.
  #
  # See Factory#wrapped_with for a convenient way to construct one of these -- although you won't
  # normally need to construct these yourself, rather a Container will wrap factories for you
  # where you add them to the container together with specific options.
  #
  # Allows you to:
  #
  # * Specify additional :features that the wrapped factory provides in this context
  #   (eg to indicate that you provide a specific named version of a more general interface,
  #    a :special_logger rather than just a Logger)
  #
  # * Fix particular initial arguments that get passed to the factory when used in this wrapped context
  #   (eg if you have a factory that takes arguments, but you want to supply those args upfront,
  #    and get a factory that just constructs a particular singleton instance; 'currying')
  #
  # * Add extra requirements to the existing dependencies for this factory. Eg if you have a dependency on
  #   some general interface (eg Logger) and you want to pin it down to a specific named version that you've
  #   made available (like :special_context_logger). Or maybe you want to make an optional dependency into
  #   a non-optional one.
  #
  # * Give a constructor block which allows you customise the way the wrapped factory's new_from_dependencies
  #   method works. It gets passed the wrapped factory, the constructor dependencies and args, and should return
  #   the constructed instance. This is for when specifying :initial_args isn't enough and you need
  #   some custom way of supplying your pre-canned arguments when constructing the thing.
  class Factory::Wrapped
    include Factory::Interface

    attr_reader :provides_features, :provides_class, :constructor_dependencies,
                :wrapped_factory, :initial_args

    OPTION_NAMES = [:args, :features, :dependencies].freeze

    def initialize(factory, options={}, &wrapped_constructor_block)
      @wrapped_factory = factory

      @provides_class = factory.provides_class

      @provides_features = factory.provides_features
      extra = options[:features] and @provides_features |= extra

      @constructor_dependencies = factory.constructor_dependencies.dup

      setter_dependencies = factory.setter_dependencies(nil).dup
      extra = options[:dependencies] and extra.each do |dep_name, extra_dep_args|
        extra_dep_options = Dependency.normalise_arg_or_args_list(extra_dep_args)
        if (dep = @constructor_dependencies[dep_name])
          @constructor_dependencies[dep_name] = dep.with_options(extra_dep_options)
        elsif (dep = setter_dependencies[dep_name])
          setter_dependencies[dep_name] = dep.with_options(extra_dep_options)
          # we only actually save this overridden set of setter_dependencies
          # if at least one override is specified; otherwise we leave it delegating
          # at runtime to the wrapped factory's setter_dependencies method,
          # since this allows it to stay instance-sensitive. see #setter_dependencies.
          @extended_static_setter_dependencies ||= setter_dependencies
        else
          raise Error, "No constructor_dependency or static setter_dependency #{arg_name.inspect} found to extend on the wrapped factory"
        end
      end

      if options[:args]
        @initial_args = options[:args]
      elsif wrapped_constructor_block
        @wrapped_constructor_block = wrapped_constructor_block
      end
    end

    def setter_dependencies(instance=nil)
      @extended_static_setter_dependencies || @wrapped_factory.setter_dependencies(instance)
    end

    def new_from_dependencies(dependencies, *other_args, &block_arg)
      if @wrapped_constructor_block
        @wrapped_constructor_block.call(dependencies, *other_args, &block_arg)
      else
        case @initial_args
        when NilClass # forgeddit
        when Array then other_args.unshift(*@initial_args)
        else other_args.unshift(@initial_args)
        end
        @wrapped_factory.new_from_dependencies(dependencies, *other_args, &block_arg)
      end
    end

    def inject_dependency(*args)
      @wrapped_factory.inject_dependency(*args)
    end

    def post_initialize(*args)
      @wrapped_factory.post_initialize(*args)
    end
  end
end
