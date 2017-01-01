class RecordingRepository < EventStoreRepository

  def type
    Recording
  end

  def apply_recording_updated(recording, event)
    recording.set_attributes(event.to_h)
  end

end

class RecordingValidator < BaseObject

  attributes :recording

  def assert_validity
  end
end

class RecordingCommandHandler < CommandHandler

  private

  def repository
    @repository ||= registry.repository_for(Recording)
  end

  def process(command)
    # TODO: - validate command
    message = "process_" + command.class.name.snake_case
    send message.to_sym, command
  end

  def process_create_recording(command)
    recording = Recording.new(command.to_h)
    RecordingValidator.new(recording: recording).assert_validity
    event = RecordingCreated.new(command.to_h)
    repository.unit_of_work(command.id) do |uow|
      uow.create
      uow.append event
    end
  end

  def process_update_recording(command)
    recording = repository.find command.id
    attrs = command.to_h
    attrs.delete :id
    recording.set_attributes attrs
    RecordingValidator.new(recording: recording).assert_validity
    event = RecordingUpdated.new(attrs)
    repository.unit_of_work(command.id) do |uow|
      uow.append event
    end
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

RELEASE_ATTRIBUTES = %I(title)

class Release < Entity
  attributes :id, *RELEASE_ATTRIBUTES

  include CrudAggregate
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
