class RepositoryProjection < BaseObject

  def initialize
    @repository = registry.repository_for type
  end

  def find(id)
    repository.find(id).to_h
  end

  # Mimic subscriber projections
  def apply(*_args);  end

  private

  attr_reader :repository

  def type
    raise "Implement in subclass! #{self.class.name}"
  end

end

class FakeRecordingProjection < RepositoryProjection

  def type
    Recording
  end

end

class SubscriberProjection < BaseObject

  def initialize
    registry.event_store.add_subscriber(self)
  end

  def find(id)
    raise "Implement in subclass! #{self.class.name}"
  end

  def apply(event)
    handler_name = "when_#{event.class.name.snake_case}".to_sym
    send handler_name, event if respond_to?(handler_name)
  end
end

class RecordingProjection < SubscriberProjection

  def initialize
    super
    @store = {}
  end

  def find(id)
    @store[id]&.clone
  end

  def when_recording_created(event)
    @store[event.id] = event.to_h
  end

  def when_recording_updated(event)
    @store[event.id].merge! event.to_h
  end

end

class ReleaseProjection < SubscriberProjection

  def initialize(recordings)
    super()
    @recordings = recordings
    @releases = {}
  end

  def find(id)
    @releases[id]&.clone
  end

  def when_release_created(event)
    release = build_release_from_event_data event
    @releases[event.id] = release
  end

  def when_release_updated(event)
    release = build_release_from_event_data event
    @releases[event.id].merge! release
  end

  def when_recording_updated(_event)
    refresh_all_tracks
  end

  private

  def build_release_from_event_data(event)
    release = event.to_h
    release[:tracks] = track_id_to_data release.fetch(:tracks)
    derive_artist_from_tracks(release)
    release
  end

  def track_id_to_data(track_ids)
    track_ids.map { |id| @recordings.find(id).to_h }
  end

  def refresh_all_tracks
    @releases.values.each do |r|
      r.fetch(:tracks).map! {|track| track.fetch(:id)}
      track_id_to_data r.fetch(:tracks)
    end
  end

  def derive_artist_from_tracks(release)
    artists = release[:tracks].map {|rec| rec[:artist]}.uniq
    release[:artist] = artists.length == 1 ? artists.first : "Various artists"
  end

end

class TotalsProjection < SubscriberProjection

  def initialize
    super
    @totals = Hash.new(0)
  end

  def when_recording_created(event)
    handle_create_event event
  end

  def when_release_created(event)
    handle_create_event event
  end

  attr_reader :totals

  private

  def handle_create_event(event)
    @totals[event.class] += 1
  end

end
