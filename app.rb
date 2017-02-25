require_relative 'base'
require_relative 'event'
require_relative 'cmd'
require_relative 'crud'
require_relative 'model'

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

    run({id: release_id, title: "So", tracks: [recording_id]},
        UpdateRelease, Release)

    run(recording_data.merge({ title:  "Sledgehammer" }),
        UpdateRecording, Recording)

    # Some failing commands, look in log for verification of failure
    run({id: "Non-existing ID", title: "Foobar"},
        UpdateRecording, Recording)

    puts
    puts "EVENT STORE ------------------------------------------------"
    pp registry.event_store

    puts
    puts "EVENT LOGG -------------------------------------------------"
    pp TheEventLogg


    puts
    puts "PROJECTIONS ------------------------------------------------"
    # FIXME lock event store
    require_relative 'read'
    puber = EventPublisher.new()
    projections = [TheReleaseProjection, TheRecordingProjection, TheTotalsProjection]
    projections.each do |pr|
      puber.add_subscriber(pr)
    end
    puber.publish(*TheEventLogg.to_a)

    p TheReleaseProjection.find release_id
    p TheRecordingProjection.find recording_id
    p TheTotalsProjection.totals
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
