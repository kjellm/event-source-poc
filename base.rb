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

  def attributes(*names)
    attr_reader(*names)

    define_singleton_method(:attribute_names) { names }

    mod = Module.new do
      define_method :initialize do |**attrs|

        attrs.each do |name, value|
          raise ArgumentError.new "Unrecognized argument: #{name}" unless names.include? name
          if respond_to? "#{name}=", true
            send "#{name}=", value
          else
            instance_variable_set "@#{name}", value
          end
        end
        super(**attrs)
      end
    end

    include mod

    names
  end

end

class BaseObject

  extend Attributes

  def initialize(*_args)
  end

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

  def command_router
    @command_router ||= CommandRouter.new
  end

  def event_store
    @event_store ||=
      EventStoreOptimisticLockDecorator.new(
        EventStoreAuditLoggDecorator.new(
          EventStorePubSubDecorator.new(
            EventStore.new)))
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

class EventStoreError < StandardError
end

class EventStoreConcurrencyError < EventStoreError
end

class Event < ValueObject
end
