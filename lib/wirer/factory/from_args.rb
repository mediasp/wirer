module Wirer
  # This is handy if you want to create a factory instance entirely from
  # supplied arguments, in particular from a supplied constructor block.
  #
  # This saves you having to create your own Factory class in almost all
  # cases.
  #
  # If you specify a :class, a default implementation will be supplied
  # for constructing instances from it, whereby dependencies are passed
  # as the last argument to the class's new method, after any other args.
  # (if the last arg is already a Hash, the dependencies will be merged
  #  into it).
  #
  # Is also aliased for convenience from Factory.new.
  #
  # Factory.new(
  #   :class => Foo,
  #   :dependencies => {
  #     :logger => Logger,
  #     :bars   => {:class => Bar, :multiple => true}
  #   }
  # ) do |depedencies, *args, &block|
  #   Foo.new(*args, dependencies, &block)
  # end
  class Factory::FromArgs
    include Factory::Interface

    OPTION_NAMES = [:class, :module, :args, :features, :dependencies, :constructor_dependencies, :setter_dependencies].freeze

    def initialize(options={}, &constructor_block)
      @provides_class = options[:class] || options[:module]

      @constructor_dependencies = {}
      (options[:constructor_dependencies] || options[:dependencies] || {}).each do |name, args|
        @constructor_dependencies[name] = Dependency.new_from_arg_or_args_list(args)
      end
      @setter_dependencies = {}
      (options[:setter_dependencies] || {}).each do |name, args|
        @setter_dependencies[name] = Dependency.new_from_arg_or_args_list(args)
      end

      @provides_features = options[:features] || []
      @constructor_block = constructor_block if constructor_block

      case @provides_class
      when ::Class
        @initial_args = options[:args] if options[:args]
      when Module
        unless @constructor_block
          raise ArgumentError, "when a Module is specified you need to supply a constructor block"
        end
      when NilClass
        @provides_class = Object
        unless @constructor_block
          raise ArgumentError, "expected a :class or a constructor block or both"
        end
      else
        raise TypeError, ":class / :module options only accept a Class or Module"
      end
    end

    attr_reader :constructor_dependencies, :provides_class,
                :provides_features, :initial_args, :wrapped_class

    # Factory::FromArgs doesn't allow you to do instance-sensitive setter-dependencies;
    # subclass or make your own factory if you want these.
    def setter_dependencies(instance=nil); @setter_dependencies; end

    def new_from_dependencies(dependencies, *other_args, &block_arg)
      if @constructor_block
        @constructor_block.call(dependencies, *other_args, &block_arg)
      else
        # The only time it allows you not to specify a constructor_block
        # is when an actual Class is supplied for provides_class.
        #
        # In this case we supply a default construction method whereby
        # dependencies are merged into a last argument:
        if other_args.last.is_a?(Hash)
          hash_arg = other_args.pop
          other_args.push(hash_arg.merge(dependencies))
        else
          other_args.push(dependencies) unless dependencies.empty?
        end
        case @initial_args
        when NilClass # forgeddit
        when Array then other_args.unshift(*@initial_args)
        else other_args.unshift(@initial_args)
        end
        @provides_class.new(*other_args, &block_arg)
      end
    end
  end

  module Factory
    # delegates to Factory::FromArgs.new
    def self.new(options, &constructor_block)
      FromArgs.new(options, &constructor_block)
    end
  end
end
