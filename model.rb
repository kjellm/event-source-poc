#
# R E L E A S E
#
# a.k.a. Album
#
# Shows an example of using CrudAggregate. All stuff rolled into one
# class. Useful for the simplest aggregates that only needs CRUD
# operations.
#

RELEASE_ATTRIBUTES = %I(id title tracks)

class ReleaseCommand < Command

  private

  def validate
    required(*RELEASE_ATTRIBUTES.map {|m| send m})
    non_blank_string(title)
  end
end

class CreateRelease < ReleaseCommand
  attributes *RELEASE_ATTRIBUTES
end

class ReleaseCreated < Event
  attributes *RELEASE_ATTRIBUTES
end

class UpdateRelease < ReleaseCommand
  attributes *RELEASE_ATTRIBUTES
end

class ReleaseUpdated < Event
  attributes *RELEASE_ATTRIBUTES
end

class Release < Entity
  attributes *RELEASE_ATTRIBUTES

  registry.command_router.register_handler(self, CreateRelease, UpdateRelease)

  include CrudAggregate

  def assert_validity
    # Do something here
  end
end

#
# R E C O R D I N G
#
# Shows an example where all the different responsibilities are
# handled by separate objects.
#

RECORDING_ATTRIBUTES = %I(id title artist duration)

class RecordingCommand < Command

  private

  def validate
    required(*RECORDING_ATTRIBUTES.map {|m| send m})
    non_blank_string(title)
    non_blank_string(artist)
    positive_integer(duration)
  end
end

class CreateRecording < RecordingCommand
  attributes *RECORDING_ATTRIBUTES
end

class RecordingCreated < Event
  attributes *RECORDING_ATTRIBUTES
end

class UpdateRecording < RecordingCommand
  attributes *RECORDING_ATTRIBUTES
end

class RecordingUpdated < Event
  attributes *RECORDING_ATTRIBUTES
end

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

  registry.command_router.register_handler(self.new, CreateRecording, UpdateRecording)

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

class Recording < Entity
  attributes *RECORDING_ATTRIBUTES
end
