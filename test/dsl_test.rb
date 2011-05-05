require 'helpers'

describe Wirer::Factory::ClassDSL do
  it "should be accessible after calling Class#wireable" do
    klass = Class.new {wireable}
    assert klass.is_a?(Wirer::Factory::ClassDSL)
  end

  it "should make the class instance itself expose Wirer::Factory::Interface" do
    klass = Class.new {wireable}
    assert klass.is_a?(Wirer::Factory::Interface)
  end

  it "should allow dependencies to be declared within the class definition" do
    dep_klass = Class.new
    klass = Class.new do
      wireable
      dependency :foo, dep_klass, :some_feature, :optional => true
      setter_dependency :bar, dep_klass, :some_other_feature, :multiple => true
    end
    foo_dep = klass.constructor_dependencies[:foo]
    assert_instance_of Wirer::Dependency, foo_dep
    assert_equal dep_klass, foo_dep.required_class
    assert_equal [:some_feature], foo_dep.required_features
    assert foo_dep.optional?

    bar_dep = klass.setter_dependencies[:bar]
    assert_instance_of Wirer::Dependency, bar_dep
    assert_equal dep_klass, bar_dep.required_class
    assert_equal [:some_other_feature], bar_dep.required_features
    assert bar_dep.multiple?
  end

  describe "setter_dependency" do
    it "should by default, define a private getter and setter for use when injecting that dependency" do
      klass = Class.new do
        wireable
        setter_dependency :bar, :bar_feature
      end
      assert klass.private_method_defined?(:bar)
      assert klass.private_method_defined?(:bar=)
    end

    it "should not define a setter if you specify :setter => false" do
      klass = Class.new do
        wireable
        setter_dependency :bar, :bar_feature, :setter => false
      end
      assert !klass.method_defined?(:bar=)
    end

    it "should make the setter public if :setter => :public specified" do
      klass = Class.new do
        wireable
        setter_dependency :bar, :bar_feature, :setter => :public
      end
      assert klass.public_method_defined?(:bar=)
    end

    it "should not define a getter if you specify :getter => false" do
      klass = Class.new do
        wireable
        setter_dependency :bar, :bar_feature, :getter => false
      end
      assert !klass.method_defined?(:bar)
    end

    it "should make the getter public if :getter => :public specified" do
      klass = Class.new do
        wireable
        setter_dependency :bar, :bar_feature, :getter => :public
      end
      assert klass.public_method_defined?(:bar)
    end
  end

  describe "dependency" do
    it "should add a private attr_reader of the same name by default" do
      klass = Class.new do
        wireable
        dependency :bar, :bar_feature
      end
      assert klass.private_method_defined?(:bar)
    end

    it "should not add an attr_reader if :getter => false" do
      klass = Class.new do
        wireable
        dependency :bar, :bar_feature, :getter => false
      end
      assert !klass.method_defined?(:bar)
    end

    it "should make the getter public if :getter => :public" do
      klass = Class.new do
        wireable
        dependency :bar, :bar_feature, :getter => :public
      end
      assert klass.public_method_defined?(:bar)
    end

  end

  it "should allow provides_features to be declared within the class definition" do
    klass = Class.new do
      wireable
      provides_feature :foo, :barr
    end
    assert_equal [:foo, :barr], klass.provides_features
  end

  it "should allow subclasses to inherit the dependencies and features of their superclass, and also to add new ones" do
    klass = Class.new do
      wireable
      dependency :foo, :foo_feature
      provides_feature :bar
    end
    subclass = Class.new(klass) do
      dependency :foo2, :foo2_feature
      provides_feature :bar2
    end
    assert_equal [:bar, :bar2], subclass.provides_features
    assert subclass.constructor_dependencies.include?(:foo)
    assert subclass.constructor_dependencies.include?(:foo2)
  end

  describe "the default supplied implementation of new_from_dependencies" do
    it "should pass dependencies Hash as a last argument to new" do
      klass = Class.new do
        wireable
        dependency :foo, :foo_feature
      end
      klass.expects(:new).with(1,2,3, :foo => "foo")
      klass.new_from_dependencies({:foo => "foo"}, 1, 2, 3)
    end

    it "should omit the dependencies hash argument to new where there are no dependencies" do
      klass = Class.new {wireable}
      klass.expects(:new).with(:foo => "foo")
      klass.new_from_dependencies({}, {:foo => "foo"})
      klass.expects(:new).with()
      klass.new_from_dependencies({})
    end

    it "should merge dependencies into a final Hash argument where one is supplied" do
      klass = Class.new do
        wireable
        dependency :foo, :foo_feature
      end
      klass.expects(:new).with(:foo => "foo", :bar => "bar")
      klass.new_from_dependencies({:foo => "foo"}, {:bar => 'bar'})
      klass.expects(:new).with(1, 2, 3, :foo => "foo", :bar => "bar")
      klass.new_from_dependencies({:foo => "foo"}, 1, 2, 3, {:bar => 'bar'})
    end
  end

  it "should allow Strings to be used for class or module names when specifying a dependency,
      to avoid cyclic load-order dependencies between classes using this DSL" do
    class FooTest
      wireable
      dependency :bar, :class => "BarTest"
    end
    class BarTest
      wireable
      dependency :foo, :class => "FooTest"
    end
    assert_equal FooTest, BarTest.constructor_dependencies[:foo].required_class
    assert_equal BarTest, FooTest.constructor_dependencies[:bar].required_class
  end

  it "should allow factory_dependency as sugar for constructor_dependency ..., :factory => true" do
    Class.new do
      wireable
      expects(:constructor_dependency).with(:foo, 'foo', :some_arg => 'foo', :factory => true)
      factory_dependency :foo, 'foo', :some_arg => 'foo'
    end
  end
end
