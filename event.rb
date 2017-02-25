class HStore

  def initialize
    @h = {}
  end

  def version
    @h.size
  end

  def [](key)
    @h[key]
  end

  def []=(key, value)
    @h[key] = value
  end

  def transaction(*_args)
    yield
  end
end

class EventStream < BaseObject

  READ_ONLY = true
  THREAD_SAFE = true

  #@store = PStore.new("events.pstore", THREAD_SAFE)
  @store = HStore.new

  def self.store
    @store
  end

  def store
    self.class.store
  end

  def initialize(id)
    @id = id
    store.transaction(!READ_ONLY) do
      store[id] = []
    end
  end

  def version
    store.transaction(READ_ONLY) do
      store[@id].length
    end
  end

  def append(*events)
    store.transaction(!READ_ONLY) do
      store[@id].push(*events)
    end
  end

  def to_a
    store.transaction(READ_ONLY) do
      store[@id].clone
    end
  end

  def inspect
    store.transaction(READ_ONLY) do
      '#<%s:0x%x @id="%s" events=%s>' %
        [self.class.name, object_id, UUID.from_int(@id), store[@id].inspect]
    end
  end

end


class EventStore < BaseObject

  def initialize
    @streams = {}
  end

  def create(id)
    id = UUID.as_int id
    raise EventStoreError, "Stream exists for #{id}" if @streams.key? id
    @streams[id] = EventStream.new(id)
    raise EventStoreError, "Stream exists for #{id}" if @streams[id].version != 0
  end

  def append(id, *events)
    id = UUID.as_int id
    @streams.fetch(id).append(*events)
  end

  def event_stream_for(id)
    id = UUID.as_int id
    @streams[id]&.clone
  end

  def event_stream_version_for(id)
    id = UUID.as_int id
    @streams[id]&.version || 0
  end
end

class EventStoreOptimisticLockDecorator < DelegateClass(EventStore)

  def initialize(obj)
    super
    @locks = {}
  end

  def create(id)
    @locks[id] = Mutex.new
    super
  end

  def append(id, expected_version, *events)
    @locks[id].synchronize do
      event_stream_version_for(id) == expected_version or
        raise EventStoreConcurrencyError
      super id, *events
    end
  end

end

class EventPublisher

  def initialize
    @subscribers = []
  end

  def subscribe(subscriber)
    @subscribers << subscriber
  end

  def publish(*events)
    events.each do |e|
      @subscribers.each do |sub|
        sub.apply e
      end
    end
  end
end



class EventStorePubSubDecorator < DelegateClass(EventStore)

  def initialize(obj)
    super
    @publisher = registry.event_publisher
  end

  def append(id, *events)
    super
    @publisher.publish(*events)
  end

end

class EventStoreLoggDecorator < DelegateClass(EventStore)

  def append(id, *events)
    super
    logg "New events: #{events}"
  end

end

class UnitOfWork < BaseObject

  def initialize(event_store, id)
    @id = id
    @event_store = event_store
    @expected_version = event_store.event_stream_version_for(id)
  end

  def create
    event_store.create id
  end

  def append(*events)
    event_store.append id, expected_version, *events
  end

  private

  attr_reader :id, :event_store, :expected_version

end

class EventStoreRepository < BaseObject

  module InstanceMethods
    def find(id)
      stream = registry.event_store.event_stream_for(id)
      return if stream.nil?
      build stream.to_a
    end

    def unit_of_work(id)
      yield UnitOfWork.new(registry.event_store, id)
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

class EventLogg < BaseObject

  STREAM_ID = 1

  def initialize
    @stream = EventStream.new(STREAM_ID)
    registry.event_publisher.subscribe self
  end

  def apply(event)
    @stream.append event
  end

  def to_a
    @stream.to_a
  end

  def inspect
    "#<EventLogg #{to_a.inspect}>"
  end

end

TheEventLogg = EventLogg.new
