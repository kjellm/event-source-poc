require 'pstore'

Object.send(:remove_const, :EventStream)

class EventStream < BaseObject

  READ_ONLY = true
  THREAD_SAFE = true

  @store = PStore.new("events.pstore", THREAD_SAFE)

  def self.store
    @store
  end

  def initialize(id)
    @id = id
    self.class.store.transaction(!READ_ONLY) do
      self.class.store[id] = []
    end
  end

  def version
    self.class.store.transaction(READ_ONLY) do
      self.class.store[@id].length
    end
  end

  def append(*events)
    self.class.store.transaction(!READ_ONLY) do
      self.class.store[@id].push(*events)
    end
  end

  def to_a
    self.class.store.transaction(READ_ONLY) do
      self.class.store[@id].clone
    end
  end

  def inspect
    self.class.store.transaction(READ_ONLY) do
      '#<%s:0x%x @id="%s" events=%s>' %
        [self.class.name, object_id, UUID.from_int(@id), self.class.store[@id].inspect]
    end
  end

end
