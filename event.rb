class EventSourceError < StandardError
end

class EventStoreConcurrencyError < EventSourceError
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

  def event_stream_version_for(id)
    streams[id]&.version || 0
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
      expected_version = registry.event_store.event_stream_version_for(id)
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
