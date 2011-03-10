# Wirer
#
# A lightweight dependency injection framework to help wire up objects in Ruby.
#
# Some usage examples for now:

container = Wirer do |c|

  # SHOWING THE CONTAINER HOW TO CONSTRUCT AN EXISTING CLASS:

  # This is registered as providing class Logger.
  # It will be constructed via Logger.new('/option_for_logger.txt')
  c.add Logger, '/option_for_logger.txt'

  # This is registered as providing class Logger, and also providing feature :special_logger
  # which can then be used to request it in particular situations
  c.add :special_logger, Logger, '/special_log.txt'

  # You can supply a custom block for constructing the dependency if you want;
  # specifying the class upfront means it still knows what class is provided by the block
  c.add(:other_special_logger, Logger) do
    Logger.new(foo, bar, baz)
  end

  # You don't actually have to specify the class that's provided; it will just
  # provide_class Object by default. In this case you really need to specify
  # a feature name for it, or else you'll have no way to refer to it:
  c.add(:mystery_meat) do
    rand(2) == 0 ? Mystery.new : Meat.new
  end

  # add_new_factory is the more explicit but verbose way to do this.
  # note in this case you need to specify a :method_name separately if you want a method defined on
  # the container for it.
  c.add_new_factory(:class => Foo, :features => [:foo, :bar], :method_name => :foo) {Foo.new(...)}
  c.add_new_factory(:class => Logger, :features => [:logger], :method_name => :logger, :args => ['/arg_for_logger.txt'])




  # SPECIFYING DEPENDENCIES (which will then automatically get constructed and passed into your constructor)


  # This will be constructed via LogSpewer.new(:logger => logger)
  c.add LogSpewer, :logger => Logger

  # however since two Loggers are available, we might want to specify
  # a particular one, by making it depend on the feature :special_logger
  # provided by only one of them
  c.add :special_log_spewer, LogSpewer, :logger => :special_logger

  # You can specify a combination of class/module and feature name requirements for a
  # dependency:
  c.add :fussy_log_spewer, LogSpewer, :logger => [SpecialLogger, :providing, :these, :features]



  # MULTIPLE AND OPTIONAL DEPENDENCIES

  # intended to be useful for extension points in plugin systems - you can have for example a
  # multiple dependency on 'anything interested in listening to me' or 'anything interested
  # in plugging in to this extension point'.

  # You can specify cardinality options on dependencies via a longer argument form:
  # by default one and only one dependency is required, but you can make it
  # :multiple to get an array of all matching dependencies.
  # This will be constructed as NoisyLogSpewer.new(:loggers => [logger1, logger2, ...])
  c.add :i_spew_to_all_logs, NoisyLogSpewer, :loggers => {:class => Logger, :multiple => true}

  # if you don't mind getting a nil if there dependency isn't available, you can make it :optional
  c.add :i_spew_to_a_log_if_present, HesitantLogSpewer, :logger => {:class => Logger, :optional => true}

  # or maybe you want as many are as available but don't mind if that number is zero:
  # if you don't mind getting a nil if there dependency isn't available, you can make it :optional
  c.add :i_spew_to_what_i_can_get, HesitantLogSpewer, :loggers => {:class => Logger, :multiple => true, :optional => true}



  # a particularly complicated dependency example:
  c.add :complicated, LogSpewer, :loggers => {:class => Logger, :features => [:foo, :bar], :multiple => true, :optional => true}


  # CUSTOM ARGS OR CONSTRUCTOR BLOCK

  # By default, dependencies are passed to the class's new method as a hash argument.
  # you can customize this with a block though:
  c.add(:foo, Foo, :logger => Logger) do |dependencies|
    Foo.new(dependencies[:logger])
  end

  # And you can specify initial :args which will be passed before the dependencies hash.
  # in this case it'll be constructed as
  #   Foo.new('initial arg', :logger => logger)
  c.add(:foo, Foo, 'initial arg', :logger => Logger)



  # If you need to specify any other keyword arguments for the factory, :dependencies need to be supplied separately, eg:
  c.add(:foo, Foo, :dependencies => {:logger => Logger}, :args => ['initial arg'], :features => [:extra, :feature, :names])




  # SETTER DEPENDENCIES AND TWO-PHASE INITIALIZATION

  # Sometimes you need depdendencies to be supplied after the object has been constructed.
  # Eg if you need to break a cyclic dependency.
  # These kinds of dependencies can be specified as :setter_dependencies.
  # An example:

  c.add(Foo, :setter_dependencies => {:bar => Bar})
  c.add(Bar, :setter_dependencies => {:bar => Foo})

  # this situation will be wired up like so:
  #
  #   foo = Foo.new
  #   bar = Bar.new
  #   foo.send(:bar=, bar)
  #   bar.send(:foo=, foo)
  #   foo.send(:post_initialize) if foo.respond_to?(:post_initialize)
  #   bar.send(:post_initialize) if bar.respond_to?(:post_initialize)
  #
  # Note you can get a post_initialize callback once your entire dependency graph
  # is wired up and ready for action.
  #
  # Note that the setters and post_initialize hook used for this purpose
  # can be private, if you want to limit them only to use by the container
  # during two-phase initialization.


  # If you need precise control over two-phase initialization, you can add your own
  # Factory provided it implements Wirer::Factory::Interface.
  #
  # The factory implementation can, if it wants, override the default mechanism for
  # injecting dependencies into instances created from it, and the default mechanism
  # for post_initializing them.
  #
  # It can also make the setter_dependencies requested conditional on the particular
  # instance constructed, which may be useful if they vary depending on arguments to
  # the constructor.
  add_factory_instance(my_custom_factory, :method_name => :my_custom_factory)



  # ADDING AN EXISTING GLOBAL OBJECT

  # Useful if you're using some (doubtless third-party ;-) library which has
  # hardcoded global state or singletons in a global scope, but you want to add them
  # to your container anyway so they at least appear as modular components for use by
  # other stuff.

  # this will work provided the global thing is not itself a class or module:
  c.add :naughty_global_state, SomeLibraryWithA::GLOBAL_THINGUMY

  # or this is more explicit:
  c.add_instance SomeLibraryWithA::GLOBAL_THINGUMY, :method_name => :naughty_global_state

  # the object will be added as providing the class of which it is an instance,
  # together with any extra feature name or names that you specify.
  # here multiple feature names are specified
  c.add :instance => SomeLibraryWithA::GLOBAL_THINGUMY, :features => [:foo, :bar]




  # NON-SINGLETON FACTORIES

  # So far every factory we added to our container has been a singleton in the scope of the container.
  # This is the default and means that the container will only ever construct one instance of it, and
  # will cache that instance.
  #
  # You can turn this off it you want though, via eg:
  c.add :foo, Foo, :singleton => false

  # The container will then construct a new instance whenever a Foo is required.
  #
  # Factories which are added as singletons can also support arguments, eg:
  #  container.foo(args, for, factory)
  #
  # These will then be passed on as additional arguments to the constructor
  # block where you supply one, eg:
  c.add(:foo, Foo, :singleton => false, :dependencies => {:logger => Logger}) do |dependencies, *other_args|
    Foo.new(other_args, dependencies[:logger])
  end

  # Where you only supply a class, by default they'll be passed as additional
  # arguments to the new method before the dependencies hash.
  # If the last argument is a hash, dependencies will be merged into it. eg:
  #
  c.add(:foo, Foo, :singleton => false, :dependencies => {:logger => Logger})
  # here,
  #   c.foo(:other => arg)
  # will lead to
  #   Foo.new(:other => arg, :logger => logger)
  # and
  #  c.foo(arg1, arg2, :arg3 => 'foo')
  # to
  #  Foo.new(arg1, arg2, :arg3 => 'foo', :logger => logger)
  #
  # If you don't like this, just make sure to supply a constructor block.



  # Note that the singleton-ness or otherwise, is not a property of the factory itself, rather
  # it's specific to the context of that factory within a particular container.

  # Note that when using non-singleton factories, all bets are off when it comes to wiring up
  # object graphs which have cycles in them - since it can't keep constructing new instances
  # all the way down.
  #
  # Similarly, if the same dependency occurs twice in your dependency graph,
  # where a non-singleton factory is used for it, you'll obviously get multiple distinct instances
  # rather than references to one shared instance.
  #
  # I considered providing more fine-grained control over this (eg making things a singleton in the
  # scope of one particular 'construction session', but able to construct new instance for each
  # such construction session) but this is out of scope for now.
end

# GETTING STUFF OUT OF A CONTAINER

# Pretty crucial eh!

# Things added via 'add' with a symbol method name as the first argument, are made available via
# corresponding methods on the container:
container.special_logger
container.mystery_meat
# You can also specify this via an explicit :method_name parameter (and in fact you need to
# specify it this if you use the slightly-lower-level add_factory / add_new_factory / add_instance
# calls)

# You can also ask the container to find any kind of dependency, via
# passing dependency specification arguments to []:
container[Logger]
container[:special_logger]
container[Logger, :multiple => true]
container[SomeClass, :and, :some, :features]
container[SomeModule]
container[SomeModule, :optional => true]
# unless you specify :optional => true, it'll whinge if the dependency can't be fulfilled.



# DSL FOR EXPRESSING DEPENDENCIES FOR A PARTICULAR CLASS
#
# This is really handy if you're writing classes which are designed to be
# components that are ready to be wired up by a Wirer::Container.
#
# Using the DSL makes your class instance itself expose Wirer::Factory::Interface,
# meaning it can be added to a container without having to manually state
# its dependencies or provided features. The container will 'just know'.
#
# (although as we shall see, you can refine the dependencies when adding it to a
# container, to override the defaults within that particular context if you need to;
# you can also specify extra provided features within the container context)

class Foo
  wireable # extends with the DSL methods (Wirer::Factory::ClassDSL)

  # Declare some dependencies.
  dependency :logger, Logger
  dependency :arg_name, DesiredClass, :other, :desired, :feature, :names, :optional => true
  dependency :arg_name, :class => DesiredClass, :features => [:desired, :feature, :names], :optional => true

  # to avoid cyclic load-order dependencies between classes using this DSL, you can specify a class or module
  # name as a string to be resolved later. In this case you need to use the explicit :class => foo args style.
  dependency :something, :class => "Some::Thing"

  # you can declare extra features which the class factory provides:
  provides_feature :foo, :bar, :baz

  # and setter dependencies
  setter_dependency :foo, Foo
  # (by default this will also define a private attr_writer :foo for you, which is
  #  what it will use by default to inject the dependency)

  # you can also override the factory methods which the class has been extended with.
  # the most common case would be where you want to customize how instances are
  # constructed from the named dependencies (and any other args), via eg:
  def self.new_from_dependencies(dependencies, *other_args)
    new(dependencies[:foo], dependencies[:bar], *other_args)
  end

  # you could also add extra instance-specific setter dependencies, eg via:
  def self.setter_dependencies(instance)
    result = super
    result[:extra] = Wirer::Dependency.new(...) if instance.something?
    result
  end

  # Or to customize the way that setter dependencies are injected:
  def self.inject_dependency(instance, arg_name, dependency)
    instance.instance_variable_set(:"@#{arg_name}", dependency)
  end
end

class Bar < Foo
  # when using Wirer::Factory::ClassDSL, subclasses inherit their superclass's dependencies
  # and features, but you can add new ones:
  dependency :another_thing, Wotsit
  provides_feature :extra

  # or override existing dependencies
  dependency :logger, :special_logger

  # or if you don't want this inheritance between the class factory instances of subclasses,
  # you can just extend with Wirer::Factory::ClassMixin instead of using the DSL, or you
  # can override constructor_dependencies / setter_dependencies / provides_features class
  # methods, or both.
end

# Adding these classes into a container is then quite simple:
Wirer do |c|

  # It will see that Foo.is_a?(Wirer::Factory::Interface) and add it directly as a factory
  # taking into account its dependencies etc

  c.add Foo

  # You can *refine* the dependencies of an existing factory when adding it, eg:

  c.add Foo, :logger => :special_logger

  # its original dependency was just on a Logger, but now it's on a Logger which also
  # provides_feature :special_logger.
  #
  # This allows you to customize which particular instance of a given dependency this
  # class gets constructed with. It will be added using a Wirer::Factory::Wrapped around
  # the original factory.

  # You can also specify extra features when adding a factory, which then give you a handle
  # by which to refer to it when you want it passed to some other thing. Eg to provide the
  # special logger above:
  c.add :special_logger, Logger

  # or both at once: adding an existing factory with some extra features and some refined
  # dependencies within this container's context.
  c.add Foo, :features => [:special_foo], :dependencies => {:logger => :special_logger}

  # (if you want to specify other arguments for Factory::Wrapped, the dependency refining
  # arguments need to go in their own :dependencies arg)

  # then could then eg
  c.add Bar, :foo => :special_foo

  # If you have an existing factory which takes arguments, you can wrap it with specific
  # (initial) arguments, allowing it to be added as a singleton, eg:
  c.add Foo, 'args', 'for', 'foo', :logger => Logger

  # or to be more explicit:
  c.add Foo, :args => ['args', 'for', 'foo'], :dependencies => {:logger => Logger}
end
