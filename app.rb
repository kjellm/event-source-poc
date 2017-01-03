require_relative 'base'
require_relative 'event'
require_relative 'cmd'
require_relative 'crud'
require_relative 'model'
require_relative 'read'

class Application < BaseObject

  def main
    puts "LOGG ---------------------------------------------------------"
    recording_id = UUID.generate
    run({id: recording_id, title: "Sledge Hammer", artist: "Peter Gabriel",
         duration: 313},
        CreateRecording, Recording)

    release_id = UUID.generate
    run({id: release_id, title: "So", tracks: []},
        CreateRelease, Release)
    run({id: release_id, tracks: [recording_id]},
        UpdateRelease, Release)
    run({id: UUID.generate, title: "Shaking The Tree",
         tracks: [recording_id]},
        CreateRelease, Release)

    run({id: recording_id, title: "Sledgehammer"},
        UpdateRecording, Recording)


    puts
    puts "EVENT STORE ------------------------------------------------"
    p registry.event_store

    puts
    puts "PROJECTIONS ------------------------------------------------"
    p ReleaseProjection.find release_id
    p RecordingProjection.find recording_id
    p TotalsProjection.totals
  end

  private

  def run(request_data, command_class, aggregate)
    logg request_data.inspect
    command_handler = registry.command_handler_for(aggregate)
    command = command_class.new(request_data)
    command_handler.handle command
  end

end

Application.new.main
