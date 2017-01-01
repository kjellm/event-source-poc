require_relative 'poc'

class RecordingsTotalProjectionClass < BaseObject

  def initialize
    registry.event_store.subscribe(self)
    @total = 0
  end

  def apply(event)
    @total += 1 if event.class == RecordingCreated
  end

  attr_reader :total

end

RecordingsTotalProjection = RecordingsTotalProjectionClass.new

class Application < BaseObject

  class UUIDGenerator

    def call
      @seq ||= 0
      @seq += 1
    end
  end

  attributes uuid: UUIDGenerator.new

  def main
    id = uuid.()
    command_handler = registry.command_handler_for(Recording)

    http_request_data = {id: id, title: "A funky tune", artist: "A Funk Odyssey"}
    logg http_request_data.inspect
    transformed_http_request_data = http_request_data
    command = CreateRecording.new(transformed_http_request_data)
    command_handler.handle(command)

    http_request_data = {id: id, title: "A funky tune (Radio Edit)", artist: "A Funk Odyssey"}
    logg http_request_data.inspect
    transformed_http_request_data = http_request_data
    command = UpdateRecording.new(transformed_http_request_data)
    command_handler.handle(command)

    puts
    p registry.event_store
    p RecordingProjection.find(id)

    puts
    id = uuid.()
    command_handler = registry.command_handler_for(Release)
    http_request_data = {id: id, title: "Test release"}
    logg http_request_data.inspect
    command = CreateRelease.new(http_request_data)
    command_handler.handle command

    http_request_data = {id: id, title: "Test release updated"}
    logg http_request_data.inspect
    command = UpdateRelease.new(http_request_data)
    command_handler.handle command

    puts
    p registry.event_store
    p ReleaseProjection.find id

    puts
    p RecordingsTotalProjection.total
  end

  private

  attr_reader :uuid
end

Application.new.main
