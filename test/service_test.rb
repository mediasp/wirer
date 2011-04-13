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
    assert instance.instance_variables.include?("@foo")
    assert instance.instance_variables.include?("@bar")
    assert_equal "abc", instance.foo
    assert_equal 123, instance.bar
  end

  it "should type-check its constructor dependency arguments, using constructor_dependencies" do
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

end
