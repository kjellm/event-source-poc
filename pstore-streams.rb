require 'pstore'

Object.send(:remove_const, :EventStream)

class EventStream < BaseObject

  @store = PStore.new("events.pstore")

  def self.store
    @store
  end

  def initialize(id)
    self.class.store.transaction do
      @id = id
      self.class.store[id] = []
    end
  end

  def version
    self.class.store.transaction do
      self.class.store[@id].length
    end
  end

  def append(*events)
    self.class.store.transaction do
      self.class.store[@id].push(*events)
    end
  end

  def to_a
    self.class.store.transaction do
      self.class.store[@id].clone
    end
  end

end
