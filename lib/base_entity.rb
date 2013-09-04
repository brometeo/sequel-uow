require 'basic_attributes'

class IdPk
  PRIMARY_KEY = {:identifier=>:id, :type=>Integer}

  def self.pk
    PRIMARY_KEY[:identifier]
  end
end

class BaseEntity < IdPk
  extend Repository::Sequel::ClassFinders
  include Repository::Sequel::InstanceFinders
  extend UnitOfWork::TransactionRegistry::FinderService::ClassMethods
  include UnitOfWork::TransactionRegistry::FinderService::InstanceMethods

  def self.inherited(base)
    # TODO :id should be a IdentityAttribute, with a setter that prevents null assignation (à la Supertype Layer)
    base.class_variable_set(:'@@attributes',{PRIMARY_KEY[:identifier]=>BasicAttributes::Attribute.new(
        PRIMARY_KEY[:identifier], PRIMARY_KEY[:type])})
    base.attach_attribute_accessors(PRIMARY_KEY[:identifier])

    base.class_variable_get(:'@@attributes')[:active] = BasicAttributes::Attribute.new(:active,TrueClass, false, true)
    base.attach_attribute_accessors(:active)

    base.instance_eval do
      def attributes
        self.class_variable_get(:'@@attributes').values
      end
    end
  end

  def self.children(*names)
    names.each do |child|
      self.class_variable_get(:'@@attributes')[child] = BasicAttributes::ChildReference.new(child)
      self.attach_attribute_accessors(child, :aggregate)
      self.define_aggregate_method(child)
    end
  end

  def self.parent(parent)
    self.class_variable_get(:'@@attributes')[parent] = BasicAttributes::ParentReference.new(parent)
    self.attach_attribute_accessors(parent, :parent)
  end

  def self.attribute(name, type, *opts)
    parsed_opts = opts.reduce({}){|m,opt| m.merge!(opt); m }
    if BaseEntity == type.superclass
      self.class_variable_get(:'@@attributes')[name] =  BasicAttributes::ValueReference.new(name, type)
    else
      self.class_variable_get(:'@@attributes')[name] =  BasicAttributes::Attribute.new(
          name, type, parsed_opts[:mandatory], parsed_opts[:default])
    end
    self.attach_attribute_accessors(name)
  end

  def initialize(in_h={}, parent=nil)
    raise ArgumentError, "BaseEntity must be initialized with a Hash - got: #{in_h.class}" unless in_h.is_a?(Hash)

    self.class.class_variable_get(:'@@attributes').each do |k,v|
      instance_variable_set("@#{k}".to_sym, v.default)
    end
    unless parent.nil?
      parent_attr = parent.class.to_s.split('::').last.underscore.downcase
      instance_variable_set("@#{parent_attr}".to_sym, parent)
    end
    load_attributes(in_h) unless in_h.empty?
  end

  def make(in_h)
    load_attributes(in_h)
  end

  # Executes a proc for each child, passing child as parameter to proc
  def each_child
    if self.class.has_children?
      self.class.child_references.each do |children_type|
        children = Array(self.send(children_type))
        children.each do |child|
          yield(child)
        end
      end
    end
  end

  def self.parent_reference
    parent = self.get_references(BasicAttributes::ParentReference)
    raise RuntimeError, "found multiple parents" if 1 < parent.size
    parent.first
  end

  def self.has_parent?
    !self.parent_reference.nil?
  end
  
  def self.child_references
    self.get_references(BasicAttributes::ChildReference)
  end

  def self.value_references
    self.get_references(BasicAttributes::ValueReference)
  end

  def self.has_children?
    !self.child_references.empty?
  end
  
  def self.has_value_references?
    !self.value_references.empty?
  end

  # TODO:
  #def eql?
  #end
  #alias_method :==, :eql?

  private
  protected
  
  def self.get_references(type)
    attrs = self.attributes
    refs = attrs.reduce([]){|m,attr| attr.is_a?(type) ? m<<attr.name : m }
    refs
  end
    

  def self.attach_attribute_accessors(name, type=:plain)
    self.class_eval do
      define_method(name){instance_variable_get("@#{name}".to_sym)}
      if :plain == type
        define_method("#{name}="){ |new_value|
          self.class.class_variable_get(:'@@attributes')[name].check_constraints(new_value)
          instance_variable_set("@#{name}".to_sym, new_value)
        }
      elsif :aggregate == type
        define_method("#{name}<<"){ |new_value|
          instance_variable_get("@#{name}".to_sym)<< new_value
        }
      end
    end
  end

  # TODO: check_reserved_keys(in_h) => :metadata

  def load_attributes(in_h)
    aggregates = {}

    in_h.each do |k,v|
      attr_obj = self.class.class_variable_get(:'@@attributes')[k]

      raise ArgumentError, "Attribute #{k} is not allowed in #{self.class}" if attr_obj.nil?

      if [BasicAttributes::Attribute, BasicAttributes::ValueReference].include?(attr_obj.class)
        send("#{k}=".to_sym, v)
      else
        attr_obj.check_constraints(v)
        aggregates[k] = v
      end
    end
    
    (aggregates.each do |k,v|
      send("make_#{k}".to_sym, v)
    end) unless aggregates.empty?
  end

  def self.define_aggregate_method(plural_child_name)
    self.class_eval do
      singular_name = plural_child_name.to_s.singularize
      klass_name = singular_name.camelize
      singular_make_method_name = "make_#{singular_name}"
      plural_make_method_name = "make_#{plural_child_name}"
      plural_add_method_name = "#{plural_child_name}<<"

      # Single-entity methods:

      define_method(singular_make_method_name) do |in_h|
        a_child = Object.const_get(klass_name).new(in_h, self)
        send(plural_add_method_name, a_child)
        a_child
      end

      # Collection methods:

      define_method(plural_make_method_name) do |in_a|
        children = []
        in_a.each do |in_h|
          children << send(singular_make_method_name, in_h)
        end
        children
      end
    end
  end

end
