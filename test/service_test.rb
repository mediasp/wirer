require 'helpers'

describe Wirer::Service do

  it "should be a convenience superclass which you can use which is extended with the DSL methods from Wirer::Factory::ClassDSL" do
    assert Wirer::Service.is_a?(Wirer::Factory::ClassDSL)
  end

  it "should define initialize to store the supplied constructor_dependencies in instance variables" do
    klass = Class.new(Wirer::Service) do
      dependency :foo, String, :getter => :public
      dependency :bar, Integer, :getter => :public
    end
    instance = klass.new(:foo => "abc", :bar => 123)
    assert_equal "abc", instance.foo
    assert_equal 123, instance.bar
  end

  it "should type-check constructor dependency arguments to 'new', using constructor_dependencies" do
    klass = Class.new(Wirer::Service) do
      dependency :foo, String
      dependency :bar, Integer, :multiple => true
      dependency :baz, :optional => true
    end

    assert_raises(ArgumentError) {klass.new}
    assert_raises(ArgumentError) {klass.new(:foo => :wrong)}
    assert_raises(ArgumentError) {klass.new(:foo => :wrong,  :bar => [123, 456])}
    assert_raises(ArgumentError) {klass.new(:foo => "right", :bar => :wrong)}
    assert_raises(ArgumentError) {klass.new(:foo => "right", :bar => nil)}
    assert_raises(ArgumentError) {klass.new(:foo => "right", :bar => [])}
    assert_raises(ArgumentError) {klass.new(:foo => "right", :bar => [:wrong])}
    assert_raises(ArgumentError) {klass.new(:foo => "right", :bar => [123, :wrong])}

    assert klass.new(:foo => "right", :bar => [123, 456])
    assert klass.new(:foo => "right", :bar => [123, 456], :baz => Object.new)
  end

  it "when using new_skipping_type_checks, should skip checks on the types of *supplied* constructor dependencies, but still complain about missing ones" do
    klass = Class.new(Wirer::Service) do
      dependency :foo, String
      dependency :bar, Integer, :multiple => true
      dependency :baz, :optional => true
    end

    # still complains if arguments are missing
    assert_raises(ArgumentError) {klass.new_skipping_type_checks}
    assert_raises(ArgumentError) {klass.new_skipping_type_checks(:foo => :wrong)}
    assert_raises(ArgumentError) {klass.new_skipping_type_checks(:bar => [123, 456])}

    # but not if they're present but of the wrong type. useful for passing mocks in a
    # unit test.
    assert klass.new_skipping_type_checks(:foo => "right", :bar => [:wrong])
    assert klass.new_skipping_type_checks(:foo => "right", :bar => [123, :wrong])
    assert klass.new_skipping_type_checks(:foo => "right", :bar => [123, 456])
    assert klass.new_skipping_type_checks(:foo => "right", :bar => [123, 456], :baz => Object.new)
  end

  it "should type-check factory dependencies passed to 'new' correctly" do
    klass = Class.new(Wirer::Service) do
      factory_dependency :foo_factory, String
      factory_dependency :bar_factory, Integer, :multiple => true
      factory_dependency :baz_factory, :optional => true
    end

    factory = stub('factory', :new => mock('whatevs'))

    assert_raises(ArgumentError) {klass.new}
    assert_raises(ArgumentError) {klass.new(:foo_factory => :wrong, :bar_factory => [factory])}
    assert_raises(ArgumentError) {klass.new(:foo_factory => factory, :bar_factory => factory)}
    assert_raises(ArgumentError) {klass.new(:foo_factory => factory, :bar_factory => [:wrong])}
    assert_raises(ArgumentError) {klass.new(:foo_factory => factory, :bar_factory => [factory], :baz_factory => :wrong)}
    assert_raises(ArgumentError) {klass.new(:foo_factory => factory, :bar_factory => [factory, :wrong])}

    assert klass.new(:foo_factory => factory, :bar_factory => [factory, factory])
    assert klass.new(:foo_factory => factory, :bar_factory => [factory, factory], :baz_factory => factory)
  end
end
