require 'forwardable'

class RepositoryProjection < BaseObject
  extend Forwardable

  def_delegators :@repository, :find

  def initialize
    @repository = registry.repository_for type
  end

end

class RecordingProjectionClass < RepositoryProjection

  def type
    Recording
  end

end

class ReleaseProjectionClass < RepositoryProjection

  def type
    Release
  end

end

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

RecordingProjection = RecordingProjectionClass.new
ReleaseProjection = ReleaseProjectionClass.new
TotalsProjection = TotalsProjectionClass.new
