require 'set'
require 'date'
require 'securerandom'

class String

  def snake_case
    split(/(?=[A-Z]+)/).map(&:downcase).join("_")
  end

end

class Hash

  def slice(*keys)
    keys.each_with_object(self.class.new) do
      |k, hash| hash[k] = self[k] if has_key?(k)
    end
  end

end

module UUID

  def self.generate
    SecureRandom.uuid
  end

  def self.as_int(uuid)
    Integer(uuid.split("-").join, 16)
  end

  def self.from_int(int)
    int.to_s(16).rjust(32, '0').split(/(\h{8})(\h{4})(\h{4})(\h{4})(\h{12})/)[1..-1].join("-")
  end

end


module Attributes

  def attributes(*mandatory_args, **args_with_defaults)
    names = [*mandatory_args, *args_with_defaults.keys]
    mandatory_args = Set.new(mandatory_args)

    attr_reader(*names)

    define_singleton_method(:attribute_names) { names }

    mod = Module.new do
      define_method :initialize do |**attrs|
        @_attributes = attrs.keys
        mandatory_args_given = mandatory_args & attrs.keys

        unless mandatory_args_given == mandatory_args
          raise ArgumentError.new("Missing arguments: " + (mandatory_args - mandatory_args_given).to_a.join(", "))
        end
        args_with_defaults.each do |name, value|
          instance_variable_set "@#{name}", value
        end

        attrs.each do |name, value|
          raise ArgumentError.new "Unrecognized argument: #{name}" unless names.include? name

          if respond_to? "#{name}=", true
            send "#{name}=", value
          else
            instance_variable_set "@#{name}", value
          end
        end
        super()
      end
    end

    include mod

    names
  end

end

class BaseObject

  extend Attributes

  module ClassAndInstanceMethods
    def logg(*args)
      print "#{DateTime.now} - ", *args
      puts
    end

    def registry
      @@registry ||= Registry.new
    end
  end
  include ClassAndInstanceMethods
  extend ClassAndInstanceMethods

  def to_h
    Hash[self.class.attribute_names.map {|name| [name, send(name)] }]
  end
end

class Registry < BaseObject

  def command_handler_for(klass)
    handler = if klass.respond_to? :handle
                klass
              else
                self.class.const_get("#{klass}CommandHandler").new
              end
    CommandHandlerLoggDecorator.new(handler)
  end

  def event_store
    @event_store ||= EventStorePubSubDecorator.new(EventStore.new)
  end

  def repository_for(klass)
    if klass < CrudAggregate
      klass
    else
      self.class.const_get("#{klass}Repository").new
    end
  end
end

class Entity < BaseObject

  def set_attributes(attrs)
    (self.class.attribute_names - [:id]).each do |name|
      instance_variable_set(:"@#{name}", attrs[name]) if attrs.key?(name)
    end
  end

end

class ValueObject < BaseObject
end
