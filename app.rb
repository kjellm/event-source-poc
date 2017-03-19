require_relative 'base'
require_relative 'event'
require_relative 'event_logg'
require_relative 'cmd'
require_relative 'crud'
require_relative 'model'
require_relative 'read'

require 'pp'

class Application < BaseObject

  def initialize
    @recording_id = UUID.generate
    @release_id = UUID.generate
    @checkpoint = Time.now
    initialize_projections
  end

  def main
    puts "AUDIT LOGG -------------------------------------------------"
    run_commands

    puts
    puts "EVENT STORE ------------------------------------------------"
    pp registry.event_store

    puts
    puts "EVENT LOGG -------------------------------------------------"
    pp TheEventLogg

    puts
    puts "PROJECTIONS ------------------------------------------------"
    peek_at_projections

    rebuild_projections_from(TheEventLogg.upto(@checkpoint))
    puts
    puts "Upto #@checkpoint"
    peek_at_projections

    rebuild_projections_from(TheEventLogg.to_a)
    puts
    puts "All"
    peek_at_projections
  end

  private

  def initialize_projections
    @the_recording_projection = RecordingProjection.new
    @the_release_projection = ReleaseProjection.new(@the_recording_projection)
    @the_totals_projection = TotalsProjection.new

    @projections = [
      @the_release_projection,
      @the_recording_projection,
      @the_totals_projection,
    ]
  end

  def rebuild_projections_from(events)
    # FIXME lock event store
    initialize_projections

    puber = EventPublisher.new()
    @projections.each {|pr| puber.add_subscriber(pr) }
    puber.publish(*events)
  end

  def peek_at_projections
    p @the_release_projection.find @release_id
    p @the_recording_projection.find @recording_id
    p @the_totals_projection.totals
  end

  def run_commands
    recording_data = {id: @recording_id, title: "Sledge Hammer",
                      artist: "Peter Gabriel", duration: 313}
    run(recording_data, CreateRecording, Recording)

    run({id: @release_id, title: "So", tracks: []},
        CreateRelease, Release)
    run({id: UUID.generate, title: "Shaking The Tree",
         tracks: [@recording_id]},
        CreateRelease, Release)

    run({id: @release_id, title: "So", tracks: [@recording_id]},
        UpdateRelease, Release)

    @checkpoint = Time.now

    run(recording_data.merge({ title:  "Sledgehammer" }),
        UpdateRecording, Recording)

    # Some failing commands, look in log for verification of failure
    run({id: "Non-existing ID", title: "Foobar"},
        UpdateRecording, Recording)
  end

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
