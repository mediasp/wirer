# Wirer

Lightweight Ruby-style dependency injection to help wire up objects and
modularise larger ruby codebases.

Wirer allows you to combine objects in a container and then to wire up those objects
by stating dependencies on other objects.  Objects can be identified by class and
by 'features'.

Wirer doesn't force you to make your code wirer aware.  You can use it as much
or as little as you want.

This readme along with yard docs are also hosted at
http://public.playlouder.com/doc/wirer.

# A Basic Example

``` ruby
require 'wirer'

# You add objects to, and get objects out of, an instance of Wirer::Container
ctr = Wirer::Container.new

# first, let's store a bit of configuration in the container
ctr.add(:db_cnx_string) { "sqlite:tmp.db" }

# now something that wants that bit of configuration
class Database
  # some sort of database abstraction library goes here...
  def initialize(cnx_string) ; end
end

# Add Database to container, stating our class and a dependency on the
# :db_cnx_string feature
ctr.add :db, Database, :cnx_string => :db_cnx_string do |deps|
  Database.new(deps[:cnx_string])
end

# lets define an object that has a dependency on the database
# using the `Wirer::Service` base class
class Users < Wirer::Service

  # declare a dependency on an object of class `Database`.  This also defines an
  # instance method, `database`, that we can use to access the object
  dependency :database, Database

  def all
    database[:users].all
  end
end

# Adding a `Wirer::Service` object to the container is a lot simpler, no need to
# declare dependencies again here.
ctr.add :users, Users

# Query the container for a `Users` object...
users = ctr[Users]

# this will fail, because the `Database` class is incomplete, but hopefully you
# get the picture at this point.
puts users.all
```

See README.rb for a boatload of usage examples for declaring dependencies and
adding objects to the container.

# You're doing it wrong, you don't need dependency injection with ruby!

We've found this to be false.  YMMV. We originally went down the god object path
using merb and sequel model, but as the software grew it became a nightmare to
test and maintain.  Screeds upon screeds of mixins and flakey
DSL magic.  Lots of singletons, and liable to break in mysterious ways when
refactoring.  We also started building in more variation in to how the
application could be deployed, so we needed a way of plugging together different
components, i.e. customer A authorises this way, customer B that way.  So we
began breaking up our codebase in to
smaller pieces, and as soon as we started doing that we needed some way to do
either service location or dependency injection.  Enter wirer.

There are plenty of other
{http://dotnetslackers.com/articles/designpatterns/InversionOfControlAndDependencyInjectionWithCastleWindsorContainerPart1.aspx
good discussions} on the web about the benefits of
using dependency injection / inversion of control, but I guess the main ones for
us at MSP were:

 - Easier to write unit tests that are actually unit tests and not integration
   tests.
 - Encourages a nice modular and OO design.
 - A standardised way of configuring system components, such as having pluggable
   behaviour, optional functionality etc.

# Dependencies, Classes and Features

Wirer exists to wire together different objects in your system using the
principles of Inversion of Control.  In the simplest case (and this will probably
be what you use 95% of the time) you will wire things up by Class, i.e.  Class Foo has
a dependency on class Bar.  Class Bar has a dependency on module Baz.

You can also wire things up using features - you can advertise what feautures
your object provides, and on the other end depend on a set of features. You come
up with  some conventions for how the combinations of features should be
interpreted, and then use these to differentiate between the different objects
in the container.  You can do some useful stuff with it (I promise), such as:

 - Distinguishing between objects of the same Class, i.e. `{:class => Logger,
   :features => [:http_logger]}` alongside `{:class => Logger, :features =>
   [:user_activity_logger]}`.
 - Using the special case default feature, i.e.  `{:class => Logger, :default
   => true}`.  If such a default is specified, this will be
   picked in the case of a tie when resolving dependencies.
 - Combining a class with some kind of function, i.e. `{:features =>
   [[:persists, User]]}` (yes, that is an array within an array).  The
   persistence gem uses this convention to find other repositories.
 - Describe the object without caring about type, i.e. `{:features =>
   [[:config, :max_user_count]]} # an integer` with `{:features =>
   [[:config, :user_api_url]]} # a URL object`

On the other, you can declare a dependency using a combination of
classes and features:

 - By just a class, i.e. `dependency :logger, Logger`.  In the case that multiple
   `Logger`s are available, the default, if specified, will be given.
 - With a strict dependency on a particular feature, i.e. `dependency :database,
   Sequel::Database, :reporting_database`, where you want an instance of a
   `Sequel::Database` that provides the `reporting_database` feature.
 - By class, preferring a certain feature if available, i.e. `dependency :logger,
   Logger, :prefer => :fast_logger`.  Wirer will give you a `fast_logger` if available,
   but will fallback to any other that is available.
 - You can also optionally depend on an object, i.e. `dependency :custom_logger,
   CustomLogger, :optional => true`
 - And allow wirer to return you multiple matches, i.e. `dependency :validators,
   Validator, :multiple => true`

# Adding objects to the container

When you add an object to a container, what you are really doing is defining a
factory that wirer can use to get at an object when it is needed.

Objects can be added to the container using the `add_*` methods (most of these
examples are using the verbose method {Wirer::Container#add_new_factory}:

 - the class of the object.  This class used to construct the object directly,
   i.e with `the_class.new`
   - `ctr.add_new_factory :class => SomeClass`
 - an optional constructor block, used by the factory for constructing the object
   in lieu of a class.
   - `ctr.add_new_factory {|deps| SomeClass.new }`
 - a convenient method name to access it from the container directly (i.e
   `ctr.some_service`).  This name also becomes a feature of the object.
   - `ctr.add :some_service, SomeClass`
 - a set of features to associate with an object
   - `ctr.add_new_factory :features => [:foo_feature, :bar_feature]`
   - `ctr.add_new_factory :features => [:foo, [:feature_group, :bar]]`
 - a set of dependencies that this object needs
   - `ctr.add_new_factory(:class => SomeClass, :dependencies => {:foo => Foo})
     # depend on an object of a particular class`
   - `ctr.add_new_factory(:dependencies => {:foo => foo_feature}) # depend on an
     object with a particular feature`
   - `ctr.add_new_factory(:dependencies => {:foo => [FooClass, :foo, :features]})
     # fruit salad`

# Using the {Wirer::Factory::ClassDSL}

Stating dependencies when adding objects to the container can be a bit clunky,
so you can use the {Wirer::Factory::ClassDSL class DSL} to state the depedencies
on the dependant.  The {Wirer::Factory::ClassDSL} can be used by including it
directly, extending {Wirer::Service}, or by calling {Class.wireable} when
defining your class.

```ruby

class FooClass
  wireable # mixes in ClassDSL

  dependency :bar, BarClass
end

```


