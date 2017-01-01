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
    p TotalsProjection.totals
  end

  private

  attr_reader :uuid
end

Application.new.main
