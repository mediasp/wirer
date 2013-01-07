# Wirer

Lightweight Ruby-style dependency injection to help wire up objects and
modularise larger ruby codebases.

Wirer allows you to combine objects in a container and then to wire up those objects
by stating dependencies on other objects.  Objects can be identified by class and
by 'features'.

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
# declare dependencies
ctr.add :users, Users

# Query the container for a `Users` object...
users = ctr[Users]

# this will fail, because the `Database` class is incomplete, but hopefully you
# get the picture at this point.
puts users.all
```

See README.rb for a boatload of usage examples for declaring dependencies and
adding objects to the container.

# Adding objects to the container

When you add an object to a container, you haven't necessarily constructed it
yet, so what you are really doing is defining a factory that wirer can use to
access an object when it is needed.

Objects can be added to the container with:

 - a set of features that allow you to arbitrarily tag an object
 - the class of the object
 - a convenient method name to access it from the container directly (i.e
   `container.some_service`)
 - an optional constructor block, used by the factory for constructing the object
 - a set of dependencies that this object needs

Which of these you supply depends on how you add them, and what you add, to the
container.

