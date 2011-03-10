require 'helpers'

describe Wirer::Dependency do
  def stub_factory(stub_methods=nil, &block)
    result = Object.new
    result.extend Wirer::Factory::Interface
    result.stubs(stub_methods) if stub_methods
    result.instance_eval(&block) if block
    result
  end

  describe :=== do
    describe "with a :class specified" do
      it "should match factories which provide_class this class or a subclass thereof" do
        @klass = Class.new
        @subclass = Class.new(@klass)
        @other_class = Class.new
        dependency = Wirer::Dependency.new(:class => @klass)
        assert_operator(dependency, :===, stub_factory(:provides_class => @klass))
        assert_operator(dependency, :===, stub_factory(:provides_class => @subclass))
        refute_operator(dependency, :===, stub_factory(:provides_class => Object))
        refute_operator(dependency, :===, stub_factory(:provides_class => @other_class))
      end
    end

    describe "with a :module specified" do
      it "should match factories which provide_class this module, or a class or module which includes it" do
        mod = @module = Module.new
        @including_klass = Class.new {include mod}
        @including_module = Module.new {include mod}
        @other_class = Class.new
        dependency = Wirer::Dependency.new(:module => @module)
        assert_operator(dependency, :===, stub_factory(:provides_class => @module))
        assert_operator(dependency, :===, stub_factory(:provides_class => @including_module))
        assert_operator(dependency, :===, stub_factory(:provides_class => @including_klass))
        refute_operator(dependency, :===, stub_factory(:provides_class => Object))
        refute_operator(dependency, :===, stub_factory(:provides_class => @other_class))
      end
    end

    describe "with :features specified" do
      it "should match factories which provides_features all the specified :features" do
        dependency = Wirer::Dependency.new(:features => [:foo, :bar])
        assert_operator(dependency, :===, stub_factory(:provides_features => [:foo, :bar]))
        assert_operator(dependency, :===, stub_factory(:provides_features => [:bar, :foo]))
        assert_operator(dependency, :===, stub_factory(:provides_features => [:foo, :bar, :baz]))
        refute_operator(dependency, :===, stub_factory(:provides_features => [:foo]))
        refute_operator(dependency, :===, stub_factory(:provides_features => []))
      end
    end

    describe "with :class and :features" do
      it "should match factories which provides_features all the specified :features" do
        klass = Class.new
        dependency = Wirer::Dependency.new(:features => [:foo, :bar], :class => klass)
        assert_operator(dependency, :===, stub_factory(:provides_features => [:foo, :bar], :provides_class => klass))
        refute_operator(dependency, :===, stub_factory(:provides_features => [:bar], :provides_class => klass))
        refute_operator(dependency, :===, stub_factory(:provides_features => [:foo, :bar], :provides_class => Object))
        refute_operator(dependency, :===, stub_factory(:provides_features => [:foo], :provides_class => Object))
      end
    end
  end

  describe :match_factories do
    describe "default cardinality (:optional => false, :multiple => false)" do
      it "should return a single factory instance" do
        dependency = Wirer::Dependency.new(:features => [:foo])
        matching = stub_factory(:provides_features => [:foo])
        assert_same matching, dependency.match_factories([matching])
      end

      it "should complain unless one and only one matching factory is available" do
        dependency = Wirer::Dependency.new(:features => [:foo])
        matching1 = stub_factory(:provides_features => [:foo])
        matching2 = stub_factory(:provides_features => [:foo])
        assert_raises(Wirer::DependencyFindingError) do
          dependency.match_factories([matching1, matching2])
        end
        assert_raises(Wirer::DependencyFindingError) do
          dependency.match_factories([])
        end
      end
    end

    describe "zero-or-one cardinality (:optional => true, :multiple => false)" do
      it "should return a single factory instance or nil where none available" do
        dependency = Wirer::Dependency.new(:features => [:foo], :optional => true)
        matching = stub_factory(:provides_features => [:foo])
        assert_same matching, dependency.match_factories([matching])
        assert_nil dependency.match_factories([])
      end

      it "should complain if multiple matching factories are available" do
        dependency = Wirer::Dependency.new(:features => [:foo], :optional => true)
        matching1 = stub_factory(:provides_features => [:foo])
        matching2 = stub_factory(:provides_features => [:foo])
        assert_raises(Wirer::DependencyFindingError) do
          dependency.match_factories([matching1, matching2])
        end
      end
    end

    describe "one-or-more cardinality (:optional => false, :multiple => true)" do
      it "should return an array of matching factories" do
        dependency = Wirer::Dependency.new(:features => [:foo], :multiple => true)
        matching1 = stub_factory(:provides_features => [:foo])
        matching2 = stub_factory(:provides_features => [:foo])
        not_matching = stub_factory(:provides_features => [:bar])
        assert_equal [matching1, matching2], dependency.match_factories([matching1, matching2, not_matching])
      end

      it "should complain if no matching factories are available" do
        dependency = Wirer::Dependency.new(:features => [:foo], :multiple => true)
        assert_raises(Wirer::DependencyFindingError) do
          dependency.match_factories([])
        end
      end
    end

    describe "zero-or-more cardinality (:optional => true, :multiple => true)" do
      it "should return an array of matching factories, which may be empty if none available" do
        dependency = Wirer::Dependency.new(:features => [:foo], :multiple => true, :optional => true)
        matching1 = stub_factory(:provides_features => [:foo])
        matching2 = stub_factory(:provides_features => [:foo])
        not_matching = stub_factory(:provides_features => [:bar])
        assert_equal [matching1, matching2], dependency.match_factories([matching1, matching2, not_matching])
        assert_equal [], dependency.match_factories([not_matching])
      end
    end
  end

end
