require_relative 'base'
require_relative 'event'
require_relative 'cmd'
require_relative 'crud'
require_relative 'model'
require_relative 'read'

require 'pp'

class Application < BaseObject

  def main
    puts "LOGG ---------------------------------------------------------"
    recording_id = UUID.generate
    recording_data = {id: recording_id, title: "Sledge Hammer",
                      artist: "Peter Gabriel", duration: 313}
    run(recording_data, CreateRecording, Recording)

    release_id = UUID.generate
    run({id: release_id, title: "So", tracks: []},
        CreateRelease, Release)
    run({id: UUID.generate, title: "Shaking The Tree",
         tracks: [recording_id]},
        CreateRelease, Release)

    run(recording_data.merge({ title:  "Sledgehammer" }),
        UpdateRecording, Recording)

    run({id: release_id, title: "So", tracks: [recording_id]},
        UpdateRelease, Release)

    # Some failing commands, look in log for verification of failure
    run({id: "Non-existing ID", title: "Foobar"},
        UpdateRecording, Recording)

    puts
    puts "EVENT STORE ------------------------------------------------"
    pp registry.event_store

    puts
    puts "PROJECTIONS ------------------------------------------------"
    p ReleaseProjection.find release_id
    p RecordingProjection.find recording_id
    p TotalsProjection.totals
  end

  private

  def run(request_data, command_class, aggregate)
    logg "Incoming request with data: #{request_data.inspect}"
    command_handler = registry.command_handler_for(aggregate)
    command = command_class.new(request_data)
    command_handler.handle command
  rescue StandardError => e
    logg "ERROR: Command #{command} failed because of: #{e}"
  end

end

Application.new.main
