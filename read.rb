RecordingProjection = RecordingRepository.new

ReleaseProjection = Release

class RecordingsTotalProjectionClass < BaseObject

  def initialize
    registry.event_store.subscribe(self)
    @total = 0
  end

  def apply(event)
    @total += 1 if event.class == RecordingCreated
  end

  attr_reader :total

end

RecordingsTotalProjection = RecordingsTotalProjectionClass.new
