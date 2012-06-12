module Wirer
  # Experimental support for visualising the dependency graph via Graphviz.
  # It's fairly quick and dirty and could probably use some further tweaks.
  #
  # Usage:
  #   viz = Wirer::Visualizer.new(app)
  #   viz.write_dot_file('/tmp/wirer.dot')
  #
  class Visualizer
    def initialize(container)
      @container = container
    end
    
    def write_dot_file(filename)
      File.open(filename, 'w') {|f| f.write(graphviz_string)}
    end
    
    def graphviz_string
      <<END
digraph dependencies {
  rankdir=LR;
  #{nodes.map {|n| node_graphviz(*n)}.join(";\n  ")}
  #{dependency_edges.map {|source,target,name| "#{node_id(*source)} -> #{node_id(*target)} [label=#{name.to_s.inspect}];\n  "}}
  #{inheritance_edges.map {|source,target| "#{node_id(*source)} -> #{node_id(*target)} [color=blue, penwidth=3];\n  "}}
}
END
    end
    
    def node_graphviz(klass=nil, features=nil)
      id, name = node_id_and_name(klass, features)
      "#{id} [label=#{name.inspect}]"
    end
    
    def node_id_and_name(klass=nil, features=nil)
      name = klass.to_s
      name << "\nFeatures: #{features.map(&:inspect).join(",\n")}" unless features.empty?
      @max_node_id ||= 0
      @nodes_to_ids ||= {}
      @nodes_to_ids[name] ||= (@max_node_id+=1)
      return @nodes_to_ids[name], name
    end
    
    def node_id(klass=nil, features=nil)
      node_id_and_name(klass, features).first
    end
    
    def node_from_factory(f, method_name=nil)
      provided_features = (f.provides_features || []).compact.uniq
      provided_features -= [method_name] if f.provides_class != Object
      provided_features -= [:default]
      [f.provides_class || Object, provided_features]
    end
    
    def node_from_dependency(dep)
      features = (dep.required_features || []).compact.uniq
      features -= [:default]      
      [dep.required_class || Object, features]
    end
    
    GENERIC_MODULES = [Object, String, Hash]
    
    def nodes
      result = @container.factories_by_method_name.map do |method_name, f|
        deps = f.constructor_dependencies.merge(f.setter_dependencies)
        deps.map {|name,dep| node_from_dependency(dep)} << node_from_factory(f, method_name)
      end.flatten(1).uniq
      modules = result.map {|mod,feat| mod}.uniq
      modules.each {|m| result << [m, []]}
      result.reject! {|mod,feat| feat.empty? && GENERIC_MODULES.include?(mod)}
      result.uniq
    end
    
    def dependency_edges
      @container.factories_by_method_name.map do |method_name, f|
        factory_node = node_from_factory(f, method_name)
        deps = f.constructor_dependencies.merge(f.setter_dependencies)
        deps.map do |name,dep|
          [factory_node, node_from_dependency(dep), name]
        end
      end.flatten(1)
    end
    
    def inheritance_edges
      n = nodes
      # brute force way to do it:
      n.map do |child|
        most_immediate_parent = nil
        n.each do |parent|
          next unless less_than(child, parent)
          if !most_immediate_parent || less_than(parent, most_immediate_parent)
            most_immediate_parent = parent
          end
        end
        [child, most_immediate_parent] if most_immediate_parent
      end.compact
    end
    
    def less_than(child, parent)
      child_class, child_features = *child
      parent_class, parent_features = *parent
      child_class ||= Object; parent_class ||= Object
      child_features ||= []; parent_features ||= []

      return false if child_class == parent_class && child_features == parent_features

      child_class <= parent_class && parent_features.all? {|pf| child_features.include?(pf)}
    end
  end
end