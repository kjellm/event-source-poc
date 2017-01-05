class RepositoryProjection < BaseObject

  def initialize
    @repository = registry.repository_for type
  end

  def find(id)
    repository.find(id).to_h
  end

  private

  attr_reader :repository

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
      track_id_to_data release.fetch(:tracks)
      @releases[event.id] = release
    when ReleaseUpdated
      release = event.to_h
      track_id_to_data release.fetch(:tracks)
      @releases[event.id].merge! release
    when RecordingUpdated
      @releases.values.each do |r|
        r.fetch(:tracks).map! {|track| track.fetch(:id)}
        track_id_to_data r.fetch(:tracks)
      end
    end
  end

  private

  def track_id_to_data(track_ids)
    track_ids.map! { |id| RecordingProjection.find(id).to_h }
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
