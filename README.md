# Wirer

Lightweight Ruby-style dependency injection to help wire up objects and modularise larger ruby codebases.

# Quick Start

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

See README.rb for a boatload of usage examples for declaring dependencies and adding objects to the container.
