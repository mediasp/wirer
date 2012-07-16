module Wirer
end

require 'wirer/factory/interface'
require 'wirer/factory/from_args'
require 'wirer/factory/wrapped'
require 'wirer/factory/from_instance'
require 'wirer/factory/class_mixins'
require 'wirer/factory/curried_dependencies'
require 'wirer/service'
require 'wirer/dependency'
require 'wirer/construction_session'
require 'wirer/container'
require 'wirer/errors'

module Kernel
  private
  def Wirer(&block)
    Wirer::Container.new(&block)
  end
end
