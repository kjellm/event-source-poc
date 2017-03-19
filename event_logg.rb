class EventLoggEntry < ValueObject
  attributes :timestamp, :event

  def initialize(event)
    super timestamp: Time.now, event: event
  end

end

class EventLogg < BaseObject

  def initialize
    @store = []
    registry.event_store.add_subscriber self
  end

  def apply(event)
    @store << EventLoggEntry.new(event)
  end

  def upto(timestamp)
    @store.take_while {|entry| entry.timestamp < timestamp}.map(&:event)
  end

  def to_a
    @store.to_a.map(&:event)
  end

end

TheEventLogg = EventLogg.new
