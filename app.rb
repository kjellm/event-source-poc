require_relative 'base'
require_relative 'event'
require_relative 'cmd'
require_relative 'crud'
require_relative 'model'
require_relative 'read'

class Application < BaseObject

  class UUIDGenerator

    def call
      @seq ||= 0
      @seq += 1
    end
  end

  attributes uuid: UUIDGenerator.new

  def main
    recording_id = uuid.()
    command_handler = registry.command_handler_for(Recording)
    run({id: recording_id, title: "A funky tune", artist: "A Funk Odyssey"},
        CreateRecording, command_handler)

    run({id: recording_id, title: "A funky tune (Radio Edit)", artist: "A Funk Odyssey"},
        UpdateRecording, command_handler)

    release_id = uuid.()
    command_handler = registry.command_handler_for(Release)
    run({id: release_id, title: "Test release"},
        CreateRelease, command_handler)
    run({id: release_id, title: "Test release updated"},
        UpdateRelease, command_handler)

    puts
    p registry.event_store
    p ReleaseProjection.find release_id
    p RecordingProjection.find recording_id
    p TotalsProjection.totals
  end

  private

  attr_reader :uuid

  def run(request_data, command_class, command_handler)
    logg request_data.inspect
    command = command_class.new(request_data)
    command_handler.handle command
  end

end

Application.new.main
