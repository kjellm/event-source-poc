class Command < ValueObject
end

class Event < ValueObject
end

class EventStream < BaseObject

  attributes :type

  def initialize(**args)
    super
    @event_sequence = []
  end

  def version
    @event_sequence.length
  end

  def append(*events)
    event_sequence.push(*events)
    logg events
  end

  def to_a
    @event_sequence.clone
  end

  private

  attr_reader :event_sequence
end

class EventStore < BaseObject

  def initialize
    @streams = {}
    @subscribers = []
  end

  def subscribe(subscriber)
    @subscribers << subscriber
  end

  def create(type, id)
    streams[id] = EventStream.new(type: type)
  end

  def append(id, expected_version, *events)
    stream = streams.fetch id
    stream.version == expected_version or
      raise EventStoreConcurrencyError
    stream.append(*events)
    publish(*events)
  end

  def event_stream_for(id)
    streams[id]&.clone
  end

  private

  attr_reader :streams, :subscribers

  def publish(*events)
    @subscribers.each do |sub|
      events.each do |e|
        sub.apply e
      end
    end
  end

end

class UnitOfWork < BaseObject

  def initialize(type, id, expected_version)
    @id = id
    @expected_version = expected_version
    @type = type
  end

  def create
    registry.event_store.create @type, @id
  end

  def append(*events)
    registry.event_store.append @id, @expected_version, *events
  end
end

class EventStoreRepository < BaseObject

  module InstanceMethods
    def find(id)
      stream = registry.event_store.event_stream_for(id).to_a
      build stream
    end

    def unit_of_work(id)
      stream = registry.event_store.event_stream_for(id)
      expected_version = stream&.version || 0
      yield UnitOfWork.new(type, id, expected_version)
    end

    private

    def build(stream)
      obj = type.new stream.first.to_h
      stream[1..-1].each do |event|
        message = "apply_" + event.class.name.snake_case
        send message.to_sym, obj, event
      end
      obj
    end
  end

  include InstanceMethods
end

class CommandHandler < BaseObject

  module InstanceMethods
    def handle(command)
      process(command)
      return
    end
  end

  include InstanceMethods

end

class CommandHandlerLoggDecorator < DelegateClass(CommandHandler)

  def initialize(obj)
    super obj
  end

  def handle(command)
    before_handle(command)
    __getobj__.handle(command)
  ensure
    after_handle(command)
  end

  def before_handle(command)
    logg command.inspect
  end

  def after_handle(command)
    logg "Done: #{command.inspect}"
  end

end

module CrudAggregate

  module ClassMethods
    def repository
      self
    end

    def process(command)
      message = "process_" + command.class.name.snake_case
      send message.to_sym, command
    end
  end

  module InstanceMethods

    def assert_validity
    end
  end

  def self.included(othermod)
    othermod.extend CommandHandler::InstanceMethods
    othermod.extend EventStoreRepository::InstanceMethods
    othermod.extend ClassMethods
    othermod.include InstanceMethods

    othermod_name = othermod.name.snake_case

    othermod.define_singleton_method("type") { othermod }

    othermod.define_singleton_method "process_create_" + othermod_name do |command|
      obj = new(command.to_h)
      obj.assert_validity
      event = self.class.const_get("#{othermod.name}Created").new(command.to_h)
      repository.unit_of_work(command.id) do |uow|
        uow.create
        uow.append event
      end
    end

    othermod.define_singleton_method "process_update_" + othermod_name do |command|
      obj = repository.find command.id
      attrs = command.to_h
      attrs.delete :id
      obj.set_attributes attrs
      obj.assert_validity
      event = self.class.const_get("#{othermod.name}Updated").new(attrs)
      repository.unit_of_work(command.id) do |uow|
        uow.append event
      end
    end

    othermod.define_singleton_method("apply_" + othermod_name + "_updated") do |obj, event|
      obj.set_attributes(event.to_h)
    end
  end
end
