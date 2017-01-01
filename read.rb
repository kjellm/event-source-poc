RecordingProjection = RecordingRepository.new

ReleaseProjection = Release

class TotalsProjectionClass < BaseObject

  def initialize
    registry.event_store.subscribe(self)
    @totals = Hash.new(0)
  end

  def apply(event)
    return unless [RecordingCreated, ReleaseCreated].include? event.class
    @totals[event.class] += 1
  end

  attr_reader :totals

end

TotalsProjection = TotalsProjectionClass.new
