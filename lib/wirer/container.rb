require 'thread'

module Wirer
  # A container is a collection of factories, together with logic for constructing
  # instances from these factories in a way that satisfies their dependencies.
  #
  # By default, a Factory acts as a singleton in the context of a Container which
  # it's added to, meaning that only one instance of that factory will be created by
  # the Container. This instance is created lazily and cached within the container.
  #
  # Alternatively if don't want this, specify :singleton => false when adding it.
  class Container
    attr_reader :factories
    attr_reader :factories_by_method_name
    attr_reader :singleton_factories_instances

    def initialize
      @singleton_factories_instances = {}
      @factories = []
      @factories_by_method_name = {}
      @construction_session = ConstructionSession.new(self)
      yield self if block_given?
    end

    # add Logger
    #
    # add :special_logger, Logger, '/special_logger.txt'
    # add :special_logger, Logger, :args => ['/special_logger.txt']
    # add(:special_logger, Logger) {|deps| Logger.new('/special_logger.txt')}
    #
    # add Thing, :logger => :special_logger
    # add Thing, :logger => :special_logger

    ADD_OPTION_NAMES = (Factory::Wrapped::OPTION_NAMES | Factory::FromArgs::OPTION_NAMES | [:method_name, :singleton]).freeze

    # Provides a bunch of different convenient argument styles for adding things
    # to the container.
    #
    # add is effectively syntactic sugar around add_factory, add_instance and add_new_factory;
    # if you prefer a more explicit approach feel free to use these directly.
    #
    # (or if you like it *really* explcit, see add_factory_instance)
    def add(*add_args, &add_block_arg)
      add_options = if add_args.last.is_a?(Hash) then add_args.pop else {} end

      (add_options[:features] ||= []) << :default if add_options.delete(:default)

      unless add_options.empty? || ADD_OPTION_NAMES.any? {|o| add_options.include?(o)}
        add_options = {:dependencies => add_options}
      end

      if add_args.first.is_a?(Symbol)
        extra_named_feature = add_args.shift
        add_options[:method_name] ||= extra_named_feature
        (add_options[:features] ||= []) << extra_named_feature
      end

      main_arg = add_args.shift
      case main_arg
      when Factory::Interface
        add_options[:args] = add_args unless add_args.empty?
        add_factory(main_arg, add_options, &add_block_arg)
      when ::Module
        add_options[:class] = main_arg
        add_options[:args] = add_args unless add_args.empty?
        add_new_factory(add_options, &add_block_arg)
      when NilClass
        add_new_factory(add_options, &add_block_arg)
      else
        add_instance(main_arg, add_options)
      end
    end

    # Adds an existing factory.
    #
    # If options for Factory::Wrapped are specified, will wrap the factory with these
    # extra options / overrides prior to adding it.
    def add_factory(factory, options={}, &wrapped_constructor_block)
      add_options = {
        :method_name => options.delete(:method_name),
        :singleton   => options.delete(:singleton)
      }
      unless options.empty? && !wrapped_constructor_block
        factory = factory.wrapped_with(options, &wrapped_constructor_block)
      end
      add_factory_instance(factory, add_options)
    end

    # Adds a new Factory::FromArgs constructed from the given args.
    def add_new_factory(options={}, &constructor_block)
      factory = Factory::FromArgs.new(options, &constructor_block)
      add_factory_instance(factory, options)
    end

    # Adds an instance wrapped via Factory::FromInstance
    def add_instance(instance, options={})
      features = options[:features]
      factory = case features
      when nil   then Factory::FromInstance.new(instance)
      when Array then Factory::FromInstance.new(instance, *features)
      else            Factory::FromInstance.new(instance, features)
      end
      add_factory_instance(factory, options)
    end

    # Adds a factory object, without any wrapping.
    # only options are :method_name, and :singleton (default true)
    def add_factory_instance(factory, options={})
      method_name = options[:method_name]
      singleton = (options[:singleton] != false)

      raise TypeError, "expected Wirer::Factory::Interface, got #{factory.class}" unless factory.is_a?(Factory::Interface)
      @factories << factory
      @singleton_factories_instances[factory] = nil if singleton
      if method_name
        @factories_by_method_name[method_name] = factory
        if respond_to?(method_name, true)
          warn("Can't add constructor method because #{method_name.inspect} already defined on container")
        else
          instance_eval <<-EOS, __FILE__, __LINE__
            def #{method_name}(*args, &block_arg)
              construct_factory_by_method_name(#{method_name.inspect}, *args, &block_arg)
            end
          EOS
        end
      end
    end

    def factory(name)
      @factories_by_method_name[name]
    end

    def construct_factory_by_method_name(method_name, *args, &block_arg)
      factory = @factories_by_method_name[method_name]
      begin
        @construction_session.construction_session do
          @construction_session.construct_factory(factory, *args, &block_arg)
        end
      rescue => exception
        exception.backtrace
        raise DependencyConstructionError.new("Unable to construct factory with name #{method_name}", $!)
      end
    end

    def [](*dep_args)
      @construction_session.construction_session do
        @construction_session.construct_dependency(Dependency.new_from_args(*dep_args))
      end
    end

    # Injects (ie monkey-patches) constructor methods into a given object,
    # which delegate to the corresponding constructor methods defined on the
    # container.
    #
    # This is primarily for use as a convenience by the top-level code which is
    # driving an application, to inject application services from a container
    # into the context of (say) an integration test or a driver script.
    #
    # If you're considering using this to supply dependencies to objects
    # *within* your application: instead you would usually want to add that object to
    # the container with dependencies specified, and let the container construct
    # it with the right dependencies. Google for discussion about 'service locator'
    # pattern vs 'dependency injection' / 'IoC container' pattern for more on this.
    def inject_methods_into(instance, *names)
      _self = self
      names.each do |name|
        class << instance; self; end.send(:define_method, name) do |*args|
          _self.construct_factory_by_method_name(name, *args)
        end
      end
    end

  end
end
