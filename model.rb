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

class Release < Entity
  attributes *RELEASE_ATTRIBUTES

  include CrudAggregate

  def assert_validity
    # Do something here
  end
end

module ReleaseCommandValidation

  private

  def validate
    non_blank_string(title)
  end
end

class CreateRelease < Command
  attributes *RELEASE_ATTRIBUTES

  include ReleaseCommandValidation

  def validate
    super
    required(*RELEASE_ATTRIBUTES.map {|m| send m})
  end
end

class ReleaseCreated < Event
  attributes *RELEASE_ATTRIBUTES
end

class UpdateRelease < UpdateCommand
  attributes Hash[RELEASE_ATTRIBUTES.zip(Array.new(1))]

  include ReleaseCommandValidation

end

class ReleaseUpdated < UpdateEvent
  attributes Hash[RELEASE_ATTRIBUTES.zip(Array.new(1))]
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

RECORDING_ATTRIBUTES = %I(id title artist duration)

module RecordingCommandValidation

  private

  def validate
    non_blank_string(title)
    non_blank_string(artist)
    positive_integer(duration)
  end
end

class CreateRecording < Command
  attributes *RECORDING_ATTRIBUTES

  include RecordingCommandValidation

  def validate
    super
    required(*RECORDING_ATTRIBUTES.map {|m| send m})
  end
end

class RecordingCreated < Event
  attributes *RECORDING_ATTRIBUTES
end

class UpdateRecording < UpdateCommand
  attributes Hash[RECORDING_ATTRIBUTES.zip(Array.new(2))]
  include RecordingCommandValidation
end

class RecordingUpdated < UpdateEvent
  attributes Hash[RECORDING_ATTRIBUTES.zip(Array.new(2))]
end

class Recording < Entity
  attributes *RECORDING_ATTRIBUTES
end
