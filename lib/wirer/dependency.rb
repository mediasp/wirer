# dependency :foo, Class, :features => [:feature, :feature], :optional => true
# dependency :foo, Class, :features => [:feature, :feature], :multiple => true
#
# dependency :foo, Class, :optional => true
# dependency :foo, :feature, :another_feature, :optional => true, :constructor => true

module Wirer

  class Dependency
    def self.new_from_args(*args)
      new(normalise_args(*args))
    end

    def self.new_from_arg_or_args_list(arg_or_args_list)
      new(normalise_arg_or_args_list(arg_or_args_list))
    end

    def self.normalise_arg_or_args_list(arg_or_args_list)
      case arg_or_args_list
      when Hash then arg_or_args_list
      when Array then normalise_args(*arg_or_args_list)
      else normalise_args(arg_or_args_list)
      end
    end

    def self.normalise_args(*args)
      options = args.last.is_a?(Hash) ? args.pop : {}
      args.each do |requirement|
        case requirement
        when Module then options[:class] = requirement
        else (options[:features] ||= []) << requirement
        end
      end
      options
    end

    OPTION_NAMES = [:class, :module, :features, :multiple, :optional]

    def initialize(options = {})
      required_class = options[:class] || options[:module]
      case required_class
      when Module
        @required_class = required_class
      when String
        @required_class_name = required_class
      when NilClass
        @required_class = nil
      else
        raise ArgumentError, "required :class for a Dependency must be a Module or Class, or a String name of a Module or Class"
      end
      @required_features = options[:features]
      @multiple = options[:multiple] || false
      @optional = options[:optional] || false
    end

    attr_reader :required_features
    def multiple?; @multiple; end
    def optional?; @optional; end

    # A string class name may be supplied as the :class arg to the constructor, in which case we only
    # attempt to resolve the actual class from it the first time .required_class is requested.
    #
    # This helps avoid introducing undesired load order dependencies between classes using Wirer::Factory::ClassDSL.
    def required_class
      return @required_class if defined?(@required_class)
      @required_class = @required_class_name.split("::").inject(Object, :const_get)
    end

    def requirements_to_s
      [
        case required_class
        when ::Class then "class #{@required_class}"
        when ::Module then "module #{@required_class}"
        end,
        @required_features && "features #{@required_features.inspect}"
      ].compact.join(" and ")
    end

    def inspect
      description = [requirements_to_s, ("optional" if @optional), ("multiple" if @multiple)].compact.join(', ')
      "#<#{self.class} on #{description}>"
    end

    def match_factories(available_factories)
      candidates = available_factories.select {|f| self === f}
      if !@multiple && candidates.length > 1
        raise DependencyFindingError, "More than one factory available matching #{requirements_to_s}"
      end
      if !@optional && candidates.length == 0
        raise DependencyFindingError, "No available factories matching #{requirements_to_s}"
      end
      candidates.map! {|c| yield c} if block_given?
      @multiple ? candidates : candidates.first
    end

    def ===(factory)
      factory.is_a?(Factory::Interface) &&
      (!required_class    || factory.provides_class <= required_class) &&
      (!@required_features || @required_features.all? {|feature| factory.provides_features.include?(feature)})
    end

    def with_options(options)
      new_options = {
        :multiple => @multiple,
        :optional => @optional,
        :class    => required_class,
        :features => @required_features
      }
      new_required_class = options[:class] and begin
        if required_class && !(new_required_class <= required_class)
          raise "Required class #{new_required_class} not compatible with existing requirement for #{required_class}"
        end
        new_options[:class] = new_required_class
      end
      new_required_features = options[:features] and begin
        new_options[:features] |= new_required_features
      end
      self.class.new(new_options)
    end
  end
end
