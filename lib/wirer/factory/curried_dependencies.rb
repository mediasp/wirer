module Wirer
  # This doesn't implement the full Factory::Interface, rather it's a simple
  # 'curried' wrapper around the new_from_dependencies method of a factory,
  # where the dependency arguments are pre-supplied.
  #
  # You can use one of these pretty much the same as a class, in that it has a
  # 'new' method, or it also implements a Proc-like interface ('call' and 'to_proc')
  # so you can also treat it like a block which constructs things.
  #
  # Factory::Interface#curry_with_dependencies is used to make these, but you'd
  # normally get one via a Wirer::Containerm by specifying a dependency with :factory => true;
  # the container will then give you a curried factory from which you can construct
  # your own instances, rather than supplying a single pre-constructed instance.
  #
  # Setter dependencies are curried in a very unoptimised way.
  class Factory::CurriedDependencies
    def initialize(construction_session, factory, dependencies)
      @factory = factory
      @dependencies = dependencies
      @construction_session = construction_session
    end

    def new(*args, &block_arg)
      setter_dependencies = @factory.setter_dependencies(nil).dup || {}

      @construction_session.construction_session do
        @construction_session.construct_factory(@factory, *args, &block_arg)
      end
    end

    alias :call :new

    # this allows it to be implicitly converted into a block argument, eg: instances = args.map(&factory)
    def to_proc
      method(:new).to_proc
    end
  end
end
