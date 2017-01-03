require_relative 'base'
require_relative 'event'
require_relative 'cmd'
require_relative 'crud'
require_relative 'model'
require_relative 'read'

class Application < BaseObject

  def main
    recording_id = UUID.generate
    command_handler = registry.command_handler_for(Recording)
    run({id: recording_id, title: "Sledge Hammer", artist: "Peter Gabriel",
         duration: 313},
        CreateRecording, command_handler)

    run({id: recording_id, title: "Sledgehammer"},
        UpdateRecording, command_handler)

    release_id = UUID.generate
    command_handler = registry.command_handler_for(Release)
    run({id: release_id, title: "So", tracks: []},
        CreateRelease, command_handler)
    run({id: release_id, tracks: [recording_id]},
        UpdateRelease, command_handler)
    run({id: UUID.generate, title: "Shaking The Tree",
         tracks: [recording_id]},
        CreateRelease, command_handler)


    puts
    p registry.event_store
    p ReleaseProjection.find release_id
    p RecordingProjection.find recording_id
    p TotalsProjection.totals
  end

  private

  def run(request_data, command_class, command_handler)
    logg request_data.inspect
    command = command_class.new(request_data)
    command_handler.handle command
  end

end

Application.new.main
