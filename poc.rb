require 'set'
require 'date'

# TODO:
#  - Add example where all concerns are merged into one class
#  - Add example for CRUD auto generated
#  - Add some projections
#  - Add pub/sub

class BaseObject

  def self.attributes(*mandatory_args, **args_with_defaults)
    names = [*mandatory_args, *args_with_defaults.keys]
    mandatory_args = Set.new(mandatory_args)

    attr_reader(*names)

    define_method(:attribute_names) { names }

    mod = Module.new do
      define_method :initialize do |**attrs|
        if self.class.superclass.is_a? BaseObject
          super_attrs = self.class.superclass.attribute_names || []
          super_given_attrs = {}
          attrs.keys.each do |an|
            if super_attrs.include? an
              super_given_attrs[an] = attrs.delete an
            end
          end
          super super_given_attrs
        end

        mandatory_args_given = mandatory_args & attrs.keys

        unless mandatory_args_given == mandatory_args
          raise ArgumentError.new("Missing arguments: " + (mandatory_args - mandatory_args_given).to_a.join(", "))
        end
        args_with_defaults.each do |name, value|
          instance_variable_set "@#{name}", value
        end

        attrs.each do |name, value|
          raise ArgumentError.new "Unrecognized argument: #{name}" unless names.include? name

          if respond_to? "#{name}=", true
            send "#{name}=", value
          else
            instance_variable_set "@#{name}", value
          end
        end
      end
    end

    include mod

    names
  end

  def logg(*args)
    print "#{DateTime.now} - ", *args
    puts
  end

  def registry
    @@registry ||= Registry.new
  end
end

class Registry < BaseObject

  def command_handler_for(klass)
    handler_class = self.class.const_get("#{klass}CommandHandler")
    CommandHandlerLoggDecorator.new(handler_class.new)
  end

  def event_store
    @event_store ||= EventStore.new
  end

  def repository_for(klass)
    self.class.const_get("#{klass}Repository").new
  end
end


class Entity < BaseObject
  attributes :id
end

class ValueObject < BaseObject

  def initialize
    freeze
  end

end

class AggregateRoot < Entity
end

class Command < BaseObject
end

class Event < BaseObject
end

class EventStream < BaseObject

  attributes :type

  def initialize(**args)
    super
    @event_sequence = []
  end

  def append(*events)
    event_sequence.push(*events)
    logg events
  end

  private

  attr_reader :event_sequence
end

class EventStore < BaseObject

  def initialize
    @streams = {}
  end

  def append(type, id, *events)
    stream = event_stream_for type, id
    stream.append(*events)
  end

  private

  attr_reader :streams

  def event_stream_for(type, id)
    streams[id] ||= EventStream.new(type: type)
  end
end

class EventStoreRepository < BaseObject
end

class CommandHandler < BaseObject

  def handle(command)
    process(command)
    return
  end
end

class CommandHandlerLoggDecorator < DelegateClass(CommandHandler)

  def initialize(obj)
    super obj
  end

  def handle(command)
    before_handle(command)
    __getobj__.handle(command)
  ensure
    after_handle(command)
  end

  def before_handle(command)
    logg command.inspect
  end

  def after_handle(command)
    logg "Done: #{command.inspect}"
  end

end

class CreateRecording < Command
  attributes :id, :title, :artist
end

class UpdateRecording < Command
  attributes :title, :artist
end

class RecordingCreated < Event
  attributes :id, :title, :artist
end

class RecordingRepository < EventStoreRepository

  def append(id, events)
    registry.event_store.append Recording, id, events
  end

end

class RecordingCommandHandler < CommandHandler

  private

  def repository
    @repository ||= registry.repository_for(Recording)
  end

  def process(command)
    # TODO: - validate command
    #       - validate recording
    #       - Use repository pattern
    #       - multiplex
    message = "process_" + command.class.name.split(/(?=[A-Z]+)/).map(&:downcase).join("_")
    send message.to_sym, command
  end

  def process_create_recording(command)
    event = RecordingCreated.new(id: command.id, title: command.title, artist: command.artist)
    repository.append command.id, event
  end


end

class Recording < AggregateRoot
  attributes :title, :artist
end

class Application < BaseObject

  class UUIDGenerator

    def call
      @seq ||= 0
      @seq += 1
    end
  end

  attributes uuid: UUIDGenerator.new

  def main
    http_request_data = {id: uuid.(), title: "A funky tune", artist: "A Funk Odyssey"}
    logg http_request_data.inspect
    transformed_http_request_data = http_request_data
    command = CreateRecording.new(transformed_http_request_data)
    command_handler = registry.command_handler_for(Recording)
    command_handler.handle(command)
    p registry.event_store
  end

  private

  attr_reader :uuid
end

Application.new.main
