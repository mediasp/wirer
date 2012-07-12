require 'helpers'

describe Wirer::Container do

  def stub_factory(stub_methods=nil, &block)
    result = Object.new
    result.extend Wirer::Factory::Interface
    result.stubs(stub_methods) if stub_methods
    result.instance_eval(&block) if block
    result
  end

  it "should be constructible via a shortcut: of 'Wirer do'" do
    container = Wirer do |container|
      # you'd call container.add etc here
    end
    assert_instance_of Wirer::Container, container
  end

  describe :add_factory_instance do
    it "should directly add an instance of Wirer::Factory to the container, making it available via the #factories" do
      factory = stub_factory
      container = Wirer::Container.new do |c|
        c.add_factory_instance(factory)
      end
      assert container.factories.include?(factory)
    end

    describe "with a name specified" do
      before do
        @factory = stub_factory
        @container = Wirer::Container.new do |c|
          c.add_factory_instance(@factory, :method_name => :test_name)
        end
      end

      it "should make the factory available by it's name via #factory[name]" do
        assert_equal @factory, @container.factory(:test_name)
      end

      it "should define a method with the given name which can be used to construct from the factory" do
        object = Object.new
        @factory.expects(:new_from_dependencies).returns(object)
        assert_equal object, @container.test_name
      end
    end

    describe "with singleton flag as true (the default)" do
      it "should add the factory as a singleton in the context of the container, meaning that only one instance gets constructed from it and this instance is cached" do
        object = Object.new
        @factory = stub_factory
        @factory.expects(:new_from_dependencies).once.returns(object) # ensures only called once!
        @container = Wirer::Container.new do |c|
          c.add_factory_instance(@factory, :method_name => :test_name, :singleton => true)
        end
        # call twice and ensure the factory only called once:
        assert_equal @container.test_name, @container.test_name
      end
    end

    describe "with singleton flag as false" do
      before do
        @factory = stub_factory do
          def new_from_dependencies(deps, *args, &block); [args, block]; end
        end
        @container = Wirer::Container.new do |c|
          c.add_factory_instance(@factory, :method_name => :test_name, :singleton => false)
        end
      end

      it "should allow multiple instances to be created from the factory, and not cache the instances" do
        # call twice and ensure the factory only called once:
        refute_same @container.test_name, @container.test_name
      end

      it "should allow the factory to be called with arguments" do
        # call twice and ensure the factory only called once:
        assert_equal [[1,2,3], nil], @container.test_name(1,2,3)
        block = Proc.new {}
        assert_equal [[4,5,6], block], @container.test_name(4,5,6,&block)
      end
    end
  end

  describe :add_instance do
    it "should allow you to add an instance which already exists to the container, via the specified :method_name" do
      @instance = Object.new
      @container = Wirer::Container.new do |c|
        c.add_instance(@instance, :method_name => :test_name)
      end
      assert_equal @instance, @container.test_name
    end

    it "should wrap with Wirer::Factory::FromInstance in order to present the same factory interface for the added instance" do
      @instance = Object.new
      @container = Wirer::Container.new do |c|
        c.add_instance(@instance, :method_name => :test_name)
      end
      assert_instance_of Wirer::Factory::FromInstance, @container.factory(:test_name)
    end

    it "should have the factory provides_class the class of the wrapped instance, making it available when requesting something of
        this class from the container" do
      @klass = Class.new; @instance = @klass.new
      @container = Wirer::Container.new do |c|
        c.add_instance(@instance)
      end
      factory = @container.factories.first
      assert_instance_of Wirer::Factory::FromInstance, factory
      assert_equal @klass, factory.provides_class
      assert_equal @instance, @container[@klass]
    end

    it "should allow you to specify extra :features for the added instance; the wrapping factory will then provides_features
        these, making the instance available when requesting these feature names from the container" do
       @instance = Object.new
       @container = Wirer::Container.new do |c|
         c.add_instance(@instance, :features => [:foo, :bar])
       end
       factory = @container.factories.first
       assert_equal [:foo, :bar], factory.provides_features
       assert_equal @instance, @container[:foo]
       assert_equal @instance, @container[:bar]
       assert_equal @instance, @container[:bar, :foo]
    end
  end

  describe :inject_methods_for do
    it "should monkey-patch methods onto an object, which delegate to factory constructor methods defined on the container" do
      @container = Wirer::Container.new do |c|
        c.add_new_factory(:method_name => :test1) {1}
        c.add_new_factory(:method_name => :test2) {2}
      end
      context = Object.new
      @container.inject_methods_into(context, :test1, :test2)
      assert_equal 1, context.test1
      assert_equal 2, context.test2
    end
  end

  describe :add_new_factory do
    it "should construct and add a Factory::FromArgs with the given arguments, passing on :method_name when adding the factory" do
      @klass = Class.new; @instance = @klass.new
      @container = Wirer::Container.new do |c|
        c.add_new_factory(:features => [:foo, :bar], :class => @klass, :method_name => :test_name) {|deps| @klass.new}
      end
      assert_instance_of Wirer::Factory::FromArgs, @container.factory(:test_name)
      # quick check that it works once added:
      assert_instance_of @klass, @container.test_name
      assert_instance_of @klass, @container[@klass]
      assert_instance_of @klass, @container[:foo]
    end
  end

  describe :add_factory do
    describe "where arguments for Factory::Wrapped are supplied" do
      it "should add the existing factory wrapped using with the given arguments, passing on :method_name when adding the factory" do
        object = Object.new
        @factory = stub_factory(:new_from_dependencies => object)
        @container = Wirer::Container.new do |c|
          c.add_factory(@factory, :features => [:extra_feature], :method_name => :test_name)
        end
        assert_instance_of Wirer::Factory::Wrapped, @container.factory(:test_name)
        assert_equal @factory, @container.factory(:test_name).wrapped_factory
        # quick check that it works once added:
        assert_equal object, @container[:extra_feature]
        assert_equal object, @container.test_name
      end

      it "should allow extra class and features requirements to be added to the dependencies of the wrapped factory (example using a ClassDSL-based factory)" do
        dep_class = Class.new do
          def initalize(name); @name = name; end
          attr_reader :name
        end
        subclass  = Class.new(dep_class)
        factory = Class.new do
          wireable
          dependency :foo, dep_class, :foo_feature, :optional => true
          setter_dependency :bar, dep_class, :bar_feature

          def initialize(deps)
            @foo = deps[:foo]
          end
          attr_reader :foo, :bar
        end
        @container = Wirer::Container.new do |c|
          c.add(:wrapped, factory, :dependencies => {
            :foo => :extra_required_foo_feature,
            :bar => [subclass, :extra_required_bar_feature]
          })

          # add some providers of dependencies from it to choose between for the above,
          # just to test that the extra more fine-grained requirements worked:
          c.add(dep_class, :features => [:foo_feature]) {flunk "not expected to pick this one!"}
          c.add(dep_class, :features => [:foo_feature, :extra_required_foo_feature])

          c.add(subclass, :features => [:bar_feature])  {flunk "not expected to pick this one!"}
          c.add(dep_class, :features => [:bar_feature, :extra_required_bar_feature]) {flunk "not expected to pick this one!"}
          c.add(subclass, :features => [:bar_feature, :extra_required_bar_feature])
        end

        wrapped = @container.factory(:wrapped)
        foo_dep = wrapped.constructor_dependencies[:foo]
        assert_equal [:foo_feature, :extra_required_foo_feature], foo_dep.required_features
        bar_dep = wrapped.setter_dependencies[:bar]
        assert_equal [:bar_feature, :extra_required_bar_feature], bar_dep.required_features
        assert_equal subclass, bar_dep.required_class

        # quick check that it worked when constructing the thing:
        assert_instance_of dep_class, @container.wrapped.foo
        assert_instance_of subclass, @container.wrapped.bar
      end
    end

    describe "where no arguments for Factory::Wrapped are supplied (that includes no method_name, which would require wrapping with an extra feature name)" do
      it "should add the factory directly" do
        factory = Class.new do
          wireable
          dependency :foo, :foo_feature
        end
        @container = Wirer::Container.new do |c|
          c.add factory
        end
        assert_same factory, @container.factories.first
      end
    end

    it "should allow non-dependency arguments to be fixed when wrapping a factory that takes args" do
      factory = Class.new do
        wireable
        dependency :foo, :foo_feature

        def initialize(arg, deps)
          @arg = arg
          @foo = deps[:foo]
        end
        attr_reader :foo, :arg
      end
      foo = Object.new
      @container = Wirer::Container.new do |c|
        c.add(:wrapped, factory, "with_this_argument_fixed")
        c.add(:foo_feature, foo)
      end
      assert_same foo, @container.wrapped.foo
      assert_equal "with_this_argument_fixed", @container.wrapped.arg
    end
  end


  describe "where a factory has straightforward constructor_dependencies" do
    it "should match appropriate factories capable of supplying the dependencies, construct the dependencies from these factories,
        and pass them in to the constructor using the specified argument names" do
      foo = mock('foo')
      @bar_klass = Class.new
      @container = Wirer::Container.new do |c|
        c.add_new_factory(:dependencies => {:foo_arg => :foo, :bar_arg => @bar_klass}, :method_name => :example) do |deps|
          deps.merge(:it_worked => true)
        end
        c.add_new_factory(:features => [:foo]) {foo}
        c.add_new_factory(:class => @bar_klass) {@bar_klass.new}
      end
      result = @container.example
      assert result[:it_worked]
      assert_instance_of @bar_klass, result[:bar_arg]
      assert_equal foo, result[:foo_arg]
    end
  end

  describe "where there are cyclic constructor_dependencies" do
    it "should complain via CyclicDependencyError if an attempt is made to construct from one of the factories responsible" do
      @foo_klass = Class.new {def initialize(deps); end}
      @bar_klass = Class.new {def initialize(deps); end}
      @container = Wirer::Container.new do |c|
        c.add_new_factory(:class => @foo_klass, :dependencies => {:bar => @bar_klass}, :method_name => :foo)
        c.add_new_factory(:class => @bar_klass, :dependencies => {:foo => @foo_klass}, :method_name => :bar)
      end

      begin
        @container.foo
        assert false, 'should have thrown an error'
      rescue Wirer::DependencyConstructionError => e
        assert e.cause.is_a? Wirer::CyclicDependencyError
      end

      begin
        @container.bar
        assert false, 'should have thrown an error'
      rescue Wirer::DependencyConstructionError => e
        assert e.cause.is_a? Wirer::CyclicDependencyError
      end
    end
  end

  describe "where a factory has setter_dependencies" do
    before do
      @foo_klass = Class.new do
        attr_accessor :bar
        private :bar=
      end
      @bar_klass = Class.new do
        attr_reader :foo
        def initialize(deps={})
          @foo = deps[:foo]
        end
      end
    end

    it "should, after construction, match appropriate factories capable of supplying the setter_dependencies, construct the
        dependencies from these factories, and inject them into the new instance via (with the default Factory implementations)
        a call to an attribute writer, which may be private" do
      @container = Wirer::Container.new do |c|
        c.add_new_factory(:class => @foo_klass, :setter_dependencies => {:bar => @bar_klass}, :method_name => :foo)
        c.add_new_factory(:class => @bar_klass)
      end
      result = @container.foo
      assert_instance_of @bar_klass, result.bar
    end

    it "should allow cyclic dependencies to be achieved, provided one of the dependencies is a setter_dependency" do
      @container = Wirer::Container.new do |c|
        c.add_new_factory(:class => @foo_klass, :setter_dependencies => {:bar => @bar_klass}, :method_name => :foo)
        c.add_new_factory(:class => @bar_klass, :dependencies => {:foo => @foo_klass})
      end
      result = @container.foo
      assert_instance_of @bar_klass, result.bar
      assert_same result.bar.foo, result
    end

    it "should allow cyclic dependencies to be achieved, no matter which order you ask for things in" do
      @container = Wirer::Container.new do |c|
        c.add_new_factory(:class => @foo_klass, :setter_dependencies => {:bar => @bar_klass}, :method_name => :foo)
        c.add_new_factory(:class => @bar_klass, :dependencies => {:foo => @foo_klass}, :method_name => :bar)
      end
      result = @container.bar
      assert_instance_of @foo_klass, result.foo
      assert_same result.foo.bar, result
    end
  end

  it "should post_initialize all instances created after their entire dependency graph has been wired up, via
      (with the default Factory implementations) calling post_initialize on the instance where it responds to it
      (post_initialize may be private)" do
    @foo_klass = Class.new do
      attr_accessor :bar
      attr_reader :post_initialized
      private
      def post_initialize
        raise "expected #bar dependency to be ready and wired itself" unless @bar && @bar.foo == self
        @post_initialized = true
      end
    end
    @bar_klass = Class.new do
      attr_accessor :foo
      attr_reader :post_initialized
      private
      def post_initialize
        raise "expected #foo dependency to be ready and wired itself" unless @foo && @foo.bar == self
        @post_initialized = true
      end
    end
    @container = Wirer::Container.new do |c|
      c.add_new_factory(:class => @foo_klass, :setter_dependencies => {:bar => @bar_klass}, :method_name => :foo)
      c.add_new_factory(:class => @bar_klass, :setter_dependencies => {:foo => @foo_klass})
    end
    result = @container.foo
    assert result.post_initialized
    assert result.bar.post_initialized
  end

  describe :add do
    before do
      @container = Wirer::Container.new
    end

    it "should accept a single factory instance, passing it to add_factory_instance" do
      factory = stub_factory
      @container.expects(:add_factory_instance).with(factory, anything)
      @container.add(factory)
    end

    it "should accept a single Class, adding a Factory::FromArgs with this as its provided_class" do
      klass = Class.new
      @container.add(klass)
      assert_equal klass, @container.factories.first.provides_class
    end

    it "should accept a single Class, adding a Factory::FromArgs with this as its provided_class" do
      klass = Class.new
      @container.add(klass)
      assert_equal klass, @container.factories.first.provides_class
      assert_instance_of klass, @container[klass]
    end

    it "should accept a single Module together with a constructor block, adding a Factory::FromArgs with this as its provided_class" do
      mod = Module.new
      @container.add(mod) {o = Object.new; o.extend(mod); o}
      assert_equal mod, @container.factories.first.provides_class
      assert_kind_of mod, @container[mod]
    end

    it "should accept a Class together with some non-Hash initial arguments" do
      klass = Struct.new(:a, :b, :c)
      @container.add klass, 'a', 123, [456]
      result = @container[klass]
      assert_equal ['a', 123, [456]], [result.a, result.b, result.c]
    end

    it "should accept :default => true as shorthand for :features => [:default] (which is preferred by default by dependencies)" do
      klass = Struct.new(:x)
      @container.add(klass, :default => true) {klass.new(1)}
      @container.add(klass) {klass.new(2)}
      assert_equal klass, @container.factories.first.provides_class
      assert_equal klass, @container.factories.first.provides_class
      assert_equal 1, @container[klass].x
    end

    it "should accept a non-class/module, non-hash object and add it wrapped as a Factory::FromInstance" do
      klass = Class.new; o = klass.new
      @container.add(o)
      assert_instance_of Wirer::Factory::FromInstance, @container.factories.first
      assert_same o, @container[klass]
    end

    it "should accept a factory instance together with some args for Factory::Wrapped, and add the wrapped factory" do
      factory = stub_factory
      @container.add factory, :features => [:foo, :bar, :baz]
      assert_instance_of Wirer::Factory::Wrapped, @container.factories.first
      assert_equal [:foo, :bar, :baz], @container.factories.first.provides_features
    end

    it "should make sure to treat as a Factory when adding a Class which is also a Wirer::Factory::Interface" do
      class_factory = Class.new {extend Wirer::Factory::Interface} # or ClassDSL which includes this
      @container.add class_factory, :features => [:some, :factory, :wrapping, :args]
      assert_instance_of Wirer::Factory::Wrapped, @container.factories.first
    end

    it "should accept an initial symbol name, which is used as the :method_name and added as a provided feature to the factory that gets added" do
      klass = Class.new
      @container.add :foo, klass
      assert_instance_of klass, @container.foo
      assert_instance_of klass, @container[:foo]

      o = Object.new
      @container.add(:bar) {o}
      assert_equal o, @container.bar
      assert_equal o, @container[:bar]

      factory = stub_factory
      @container.add :foo, factory
      assert_equal [:foo], @container.factory(:foo).provides_features
    end

    it "should accept a Hash of dependencies by arg name when adding a Class (provided there is no overlap with the other option names used by add)" do
      klass = Class.new; dep_class = Class.new
      @container.add :foo, klass, :example_dep => dep_class
      factory = @container.factory(:foo)
      assert factory.constructor_dependencies.has_key?(:example_dep)
      assert_equal dep_class, factory.constructor_dependencies[:example_dep].required_class
    end

    it "should accept a Hash of dependency refinements by arg name when adding an existing Factory (provided there is no overlap with the other option names used by add)" do
      dep_class = Class.new
      factory = Wirer::Factory::FromArgs.new(:dependencies => {:example_dep => Object}) { Object.new }

      @container.add :foo, factory, :example_dep => :extra_required_feature

      factory = @container.factory(:foo)
      assert_equal [:extra_required_feature], factory.constructor_dependencies[:example_dep].required_features
    end

    it "should accept a more verbose form with keyed arguments for initial arguments, dependencies etc when this is desired or necessary" do
      klass = Struct.new(:a, :b, :deps); dep_class = Class.new
      @container.add(:foo,
        :class               => klass,
        :args                => [1,2],
        :dependencies        => {:foo => dep_class},
        :setter_dependencies => {:bar => dep_class}
      )
      @container.add(dep_class)
      factory = @container.factory(:foo)
      assert_equal klass, factory.provides_class
      assert factory.constructor_dependencies.has_key?(:foo)
      assert factory.setter_dependencies.has_key?(:bar)
    end
  end

  describe "with dependencies that are :factory => true" do
    class Foo
      def initialize(arg, deps); @deps = deps; @arg = arg; end
      attr_reader :deps, :arg
    end
    class Baz; end

    describe "when the dependency can be met by non-singleton factory" do
      # the main use case:
      # when you have a factory which takes extra arguments beyond just its dependencies, and you want to get it injected as a dependency with its own dependencies pre-supplied.
      it "should, instead of supplying a constructed instance for these dependencies, supply a factory-like object responding to :new or :call, which comes with its own constructor dependencies pre-supplied but allows the receiver to construct their own instance(s) as desired" do
        container = Wirer::Container.new do |c|
          c.add_new_factory(:class => Baz)
          c.add_new_factory(:class => Foo, :dependencies => {:baz => Baz}, :singleton => false)
          c.add_new_factory(:method_name => :bar, :dependencies => {:foo_factory => {:class => Foo, :factory => true}}) {|deps| deps}
        end

        bar = container.bar
        foo1, foo2 = bar[:foo_factory].new(123), bar[:foo_factory].call(456)

        assert_instance_of Foo, foo1
        assert_instance_of Foo, foo2
        refute_same foo1, foo2

        assert_instance_of Baz, foo1.deps[:baz]
        assert_instance_of Baz, foo2.deps[:baz]

        assert_equal 123, foo1.arg
        assert_equal 456, foo2.arg
      end
    end

    describe "when the dependency is met by a factory which was added to the container as a singleton (the default behaviour)" do
      it "should refuse to supply it as a factory dependency, since this would allow it to be called multiple times to construct multiple instances" do
        # TODO: we could enforce the container-local singleton behaviour inside the curried wrapper object we return;
        # but this is fiddly and not yet run into a use case for it
        container = Wirer::Container.new do |c|
          c.add_new_factory(:class => Foo, :features => [:foo]) {Object.new}
          c.add_new_factory(:method_name => :bar, :dependencies => {:foo => {:class => Foo, :factory => true}}) {|deps| shouldnt_get_here}
        end
        assert_raises(Wirer::DependencyConstructionError) do
          container.bar
        end
      end

    end

    describe "bad factory" do
      it "should barf with the right error if the factory can't create the dependency" do

        class FailFactory
          extend Wirer::Factory::Interface

          def self.new_from_dependencies(dependencies, *args)
            raise "my toast is burnt"
          end
        end

        container = Wirer::Container.new do |c|
          c.add_factory(FailFactory, :method_name => 'failure')
        end

        exception = assert_raises Wirer::DependencyConstructionError do
          container.failure
        end
        assert "my toast is burnt", exception.wrapped_error.message

      end
    end

    it "Dependency#check_argument should accept a factory-like object responding to new" do
      dep = Wirer::Dependency.new_from_args(:class => Foo, :factory => true)
      dep.check_argument(:foo, stub(:new => Object.new))
      assert true
    end
  end

  describe "can use setter dependencies when created from a factory dependency" do
    it "sets the setter dependency on the factory dependency" do
      foo = Class.new

      bar = Class.new do
        wireable
        setter_dependency :foo, foo
      end

      baz = Class.new(Wirer::Service) do
        factory_dependency :bar, bar
      end

      container = Wirer::Container.new do |c|
        c.add :baz, baz, :singleton => false
        c.add :bar, bar, :singleton => false
        c.add :foo, foo
      end
      
      assert container.bar.send(:foo)
      dependency_with_factory = container.baz
      factory_dependency = dependency_with_factory.send(:bar)
      assert factory_dependency.new.send(:foo)
    end
  end
end
