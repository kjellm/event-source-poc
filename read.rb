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

class RecordingProjection < RepositoryProjection

  def type
    Recording
  end

end

class SubscriberProjection < BaseObject

  def initialize
    registry.event_store.subscribe(self)
  end

end

class ReleaseProjection < SubscriberProjection

  def initialize
    super
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
    track_ids.map! { |id| TheRecordingProjection.find(id).to_h }
  end
end

class TotalsProjection < SubscriberProjection

  def initialize
    super
    @totals = Hash.new(0)
  end

  def apply(event)
    return unless [RecordingCreated, ReleaseCreated].include? event.class
    @totals[event.class] += 1
  end

  attr_reader :totals

end

TheRecordingProjection = RecordingProjection.new
TheReleaseProjection = ReleaseProjection.new
TheTotalsProjection = TotalsProjection.new
