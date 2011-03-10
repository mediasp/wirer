module Wirer
  # You can extend a Class instance directly with this if you want
  # the class itself to be usable as a factory, exposing
  # Wirer::Factory::Interface.
  #
  # By default, new_from_dependencies will call new on the class
  # with the hash of dependencies as the last argument (or merged
  # into the last argument where this is already a Hash). If you
  # don't like this you may want to override the new_from_dependencies
  # class method.
  #
  # You'll still probably want to override some of
  #   constructor_dependencies, provides_features, setter_dependencies;
  # if you'd prefer to do this via a handy DSL, instead see
  # See Wirer::Factory::ClassDSL.
  module Factory::ClassMixin
    include Factory::Interface

    def provides_class; self; end

    def new_from_dependencies(dependencies, *other_args, &block_arg)
      if other_args.last.is_a?(Hash)
        hash_arg = other_args.pop
        other_args.push(hash_arg.merge(dependencies))
      else
        other_args.push(dependencies) unless dependencies.empty?
      end
      new(*other_args, &block_arg)
    end
  end

  # A more convenient form of Wirer::Factory::ClassMixin, this additionally adds some
  # private DSL methods which let you declare your constructor_dependencies,
  # setter_dependencies and provides_features.
  #
  # The DSL works nicely with respect to subclassing, so you can add extra dependencies
  # or features in a subclass.
  module Factory::ClassDSL
    include Factory::ClassMixin

    def constructor_dependencies
      @constructor_dependencies ||= (superclass.is_a?(Factory::Interface) ? superclass.constructor_dependencies.dup : {})
    end

    # the supplied implementation of setter_dependencies does not allow for them varying dependening on the
    # instance passed; if you want to specify setter_dependencies on an instance-sensitive basis you'll need
    # to override this yourself.
    def setter_dependencies(instance=nil)
      @setter_dependencies ||= (superclass.is_a?(Factory::Interface) ? superclass.setter_dependencies.dup : {})
    end

    def provides_features
      @provides_features ||= (superclass.is_a?(Factory::Interface) ? superclass.provides_features.dup : [])
    end

  private

    def provides_feature(*args)
      provides_features.concat(args)
    end

    def add_dependency(type, arg_name, *dependency_args)
      deps_hash = type == :setter ? setter_dependencies : constructor_dependencies
      deps_hash[arg_name] = Dependency.new_from_args(*dependency_args)
    end

    # as a convenience, will additionally define a public attr_reader for this dependency name if
    # :getter => true if passed
    def constructor_dependency(name, *args)
      if args.last.is_a?(Hash) && args.last.delete(:getter)
        attr_reader(name)
        public(name)
      end
      add_dependency(:constructor, name, *args)
    end
    alias :dependency :constructor_dependency

    # will additionally define a attr_writer method of this name, unless :setter => false
    # is specified. this is private by default but made public if you specify :setter => :public.
    #
    # and a corresponding public attr_reader too if :accessor => true if specified.
    def setter_dependency(name, *args)
      options = args.last.is_a?(Hash) ? args.last : {}
      accessor = options.delete(:accessor)
      setter = options.delete(:setter)
      if (setter != false) || accessor
        attr_writer(name)
        setter == :public ? public(:"#{name}=") : private(:"#{name}=")
      end
      if accessor
        attr_reader(name)
        public(name)
      end

      add_dependency(:setter, name, *args)
    end
  end
end

class Class
  def wireable
    extend Wirer::Factory::ClassDSL
  end
end
