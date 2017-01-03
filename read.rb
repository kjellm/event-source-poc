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

class ReleaseProjectionClass < BaseObject

  def initialize
    registry.event_store.subscribe(self)
    @releases = {}
  end

  def find(id)
    @releases[id].clone
  end

  def apply(event)
    case event
    when ReleaseCreated
      release = event.to_h
      release.fetch(:tracks).map! { |id| RecordingProjection.find(id).to_h }
      @releases[event.id] = release
    when ReleaseUpdated
      release = event.to_h
      release[:tracks]&.map! { |id| RecordingProjection.find(id).to_h }
      @releases[event.id].merge! release
    when RecordingUpdated
      @releases.each do |r|
        r.fetch(:tracks).map! { |track| RecordingProjection.find(track.id).to_h }
      end
    end
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
