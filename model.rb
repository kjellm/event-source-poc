#
# R E L E A S E
#
# Shows an example of using CrudAggregate. All stuff rolled into one
# class. Useful for the simplest aggregates that only needs CRUD
# operations.
#

RELEASE_ATTRIBUTES = %I(title)

class Release < Entity
  attributes :id, *RELEASE_ATTRIBUTES

  include CrudAggregate

  def assert_validity
    # Do something here
  end
end

class CreateRelease < Command
  attributes :id, *RELEASE_ATTRIBUTES
end

class UpdateRelease < Command
  attributes :id, *RELEASE_ATTRIBUTES
end

class ReleaseCreated < Event
  attributes :id, *RELEASE_ATTRIBUTES
end

class ReleaseUpdated < Event
  attributes(*RELEASE_ATTRIBUTES)
end

#
# R E C O R D I N G
#
# Shows an example where all the different responsibilities are
# handled by separate objects.
#

class RecordingRepository < EventStoreRepository

  def type
    Recording
  end

  def apply_recording_updated(recording, event)
    recording.set_attributes(event.to_h)
  end

end

class RecordingValidator < BaseObject

  def initialize(obj)
  end

  def assert_validity
    # Do something here
  end
end

class RecordingCommandHandler < CrudCommandHandler

  private

  def type; Recording; end

  def repository
    @repository ||= registry.repository_for(Recording)
  end

  def validator(obj)
    RecordingValidator.new(obj)
  end

  def process_create_recording(command)
    process_create(command)
  end

  def process_update_recording(command)
    process_update(command)
  end
end

RECORDING_ATTRIBUTES = %I(title artist)

class UpdateRecording < Command
  attributes :id, *RECORDING_ATTRIBUTES
end

class CreateRecording < Command
  attributes :id, *RECORDING_ATTRIBUTES
end

class RecordingCreated < Event
  attributes :id, *RECORDING_ATTRIBUTES
end

class RecordingUpdated < Event
  attributes(*RECORDING_ATTRIBUTES)
end

class Recording < Entity
  attributes :id, *RECORDING_ATTRIBUTES
end
