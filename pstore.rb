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
