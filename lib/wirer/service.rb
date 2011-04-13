module Wirer
  # This is a small convenience superclass which you can (but needn't if you'd rather not)
  # inherit from when making wireable classes.
  #
  # It comes pre-extended with Wirer::Factory::ClassDSL, and it defines initialize for
  # you to save each constructor dependency in an appropriately-named instance variable.
  # (note that the 'dependency' class method will also have declared an attr_reader
  #  with this name too, so you'll be able to get at it that way also.)
  #
  # The constructor also type-checks the arguments to ensure that it has indeed
  # been supplied with all the right dependencies that it was expecting.
  # Since we have the metadata lying around for what is required, may as well take
  # advantage of it. This is most handy if you're constructing instances manually
  # rather than via a Wirer::Container -- eg in unit tests.
  #
  # It also sets a straightforward convention for arguments to the constructor:
  # dependencies and other arguments are given in a single Hash argument.
  class Service
    extend Factory::ClassDSL

    class << self; alias :new_from_dependencies :new; end

    def initialize(dependencies={})
      raise ArgumentError, "expected a Hash of dependencies" unless dependencies.is_a?(Hash)
      self.class.constructor_dependencies.each do |name, dependency|
        value = dependencies[name]
        dependency.type_check_argument(name, value)
        instance_variable_set(:"@#{name}", value)
      end
    end
  end
end
