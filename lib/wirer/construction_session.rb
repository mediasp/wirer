require 'thread'
module Wirer
  class ConstructionSession
    attr_reader :container

    def initialize(container)
      @construction_mutex = Mutex.new
      @container = container
    end

    # N.B. all calls to the private construct_ methods below must be wrapped with
    # this at the top-level entry point.
    # It wraps with a mutex, to avoid race conditions with concurrent
    # attempts to construct a singleton factory, and also ensures that everything
    # constructed in this session gets post_initialized at the end.
    def construction_session
      @construction_mutex.synchronize do
        begin
          @phase_1_in_progress = []
          @queued_for_phase_2 = []
          @queued_for_post_initialize = []

          result = yield

          until @queued_for_phase_2.empty?
            factory_instance = @queued_for_phase_2.pop
            construct_and_inject_setter_dependencies(*factory_instance)
            @queued_for_post_initialize.push(factory_instance)
          end

          result
        ensure
          post_initialize(@queued_for_post_initialize)
          remove_instance_variable(:@phase_1_in_progress)
          remove_instance_variable(:@queued_for_post_initialize)
        end
      end
    end

    def construct_dependencies(dependencies)
      result = {}
      dependencies.each do |arg_name, dependency|
        result[arg_name] = construct_dependency(dependency)
      end
      result
    end

    def construct_dependency(dependency)
      dependency.match_factories(@container.factories) do |factory|
        if dependency.factory?
          if @container.singleton_factories_instances.has_key?(factory)
            raise Error, "Problem with :factory => true dependency: #{factory} was added to the container as a singleton, so only a singleton instance can be supplied, not a wrapped factory"
          end
          curry_factory_with_constructed_dependencies(factory)
        else
          construct_factory_without_args(factory)
        end
      end
    end

    def construct_factory(factory, *args, &block_arg)
      if args.empty? && !block_arg
        construct_factory_without_args(factory)
      else
        construct_factory_with_args(factory, *args, &block_arg)
      end
    end

    def construct_factory_without_args(factory)
      instance = @container.singleton_factories_instances[factory] and return instance

      if @phase_1_in_progress.include?(factory)
        cycle = @phase_1_in_progress[@phase_1_in_progress.index(factory)..-1] + [factory]
        raise CyclicDependencyError, "Cyclic constructor dependencies. Break the cycle by changing some into setter dependencies:\n#{cycle.map(&:inspect).join("\n")}"
      end
      @phase_1_in_progress.push(factory)
      result = construct_with_constructor_dependencies(factory)
      @phase_1_in_progress.pop

      if @container.singleton_factories_instances.has_key?(factory)
        @container.singleton_factories_instances[factory] = result
      end

      @queued_for_phase_2.push([factory, result])
      result
    end

    def construct_factory_with_args(factory, *args, &block_arg)
      result = construct_with_constructor_dependencies(factory, *args, &block_arg)
      @queued_for_phase_2.push([factory, result])
      result
    end

    def construct_with_constructor_dependencies(factory, *args, &block_arg)
      deps = construct_dependencies(factory.constructor_dependencies)
      begin
        factory.new_from_dependencies(deps, *args, &block_arg)
      rescue Wirer::Error
        raise
      rescue => e
        wrapped = DependencyConstructionError.new("Unable to construct factory: #{factory.inspect}", e)
        raise wrapped
      end
    end

    def curry_factory_with_constructed_dependencies(factory)
      deps = construct_dependencies(factory.constructor_dependencies)
      factory.curry_with_dependencies(deps, self)
    end

    def construct_and_inject_setter_dependencies(factory, instance)
      setter_deps = construct_dependencies(factory.setter_dependencies(instance))
      setter_deps.each do |dep_name, dep|
        factory.inject_dependency(instance, dep_name, dep)
      end
    end

    def post_initialize(factories_instances)
      factories_instances.each {|factory, instance| factory.post_initialize(instance)}
    end

  end
end
