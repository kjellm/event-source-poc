require 'set'
require 'date'

# TODO:
#  - Add example where all concerns are merged into one class
#  - Add some projections
#  - Add pub/sub

class BaseObject

  def self.attributes(*mandatory_args, **args_with_defaults)
    names = [*mandatory_args, *args_with_defaults.keys]
    mandatory_args = Set.new(mandatory_args)

    attr_reader(*names)

    define_singleton_method(:attribute_names) { names }

    mod = Module.new do
      define_method :initialize do |**attrs|

        # FIXME: fix inheritance
        # if self.class.superclass < BaseObject
        #   if self.class.superclass.respond_to? :attribute_names
        #     super_attrs = self.class.superclass.attribute_names
        #     super_given_attrs = {}
        #     attrs.keys.each do |an|
        #       if super_attrs.include? an
        #         super_given_attrs[an] = attrs.delete an
        #       end
        #     end
        #     super super_given_attrs
        #   end
        # end

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

  def self.logg(*args)
    print "#{DateTime.now} - ", *args
    puts
  end

  def logg(*args)
    self.class.logg(*args)
  end

  def self.registry
    @@registry ||= Registry.new
  end

  def registry
    self.class.registry
  end

  def to_h
    Hash[self.class.attribute_names.map {|name| [name, send(name)] }]
  end
end

class Registry < BaseObject

  def command_handler_for(klass)
    handler = if klass.respond_to? :handle
                klass
              else
                self.class.const_get("#{klass}CommandHandler").new
              end
    CommandHandlerLoggDecorator.new(handler)
  end

  def event_store
    @event_store ||= EventStore.new
  end

  def repository_for(klass)
    self.class.const_get("#{klass}Repository").new
  end
end

class Entity < BaseObject
  # FIXME: attributes :id

  def set_attributes(attrs)
    (self.class.attribute_names - [:id]).each do |name|
      instance_variable_set(:"@#{name}", attrs[name]) if attrs.key?(name)
    end
  end

end

class ValueObject < BaseObject

  def initialize
    freeze
  end

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

  def to_a
    @event_sequence.clone
  end

  private

  attr_reader :event_sequence
end

class EventStore < BaseObject

  def initialize
    @streams = {}
  end

  def create(type, id)
    streams[id] = EventStream.new(type: type)
  end

  def append(id, *events)
    stream = streams.fetch id
    stream.append(*events)
  end

  def event_stream_for(id)
    streams[id].clone
  end

  private

  attr_reader :streams

end

class EventStoreRepository < BaseObject

  module InstanceMethods
    def create(id)
      registry.event_store.create type, id
    end

    def append(id, events)
      registry.event_store.append id, events
    end

    def find(id)
      stream = registry.event_store.event_stream_for(id).to_a
      build stream
    end

    private

    def build(stream)
      obj = type.new stream.first.to_h
      stream[1..-1].each do |event|
        message = "apply_" + event.class.name.split(/(?=[A-Z]+)/).map(&:downcase).join("_")
        send message.to_sym, obj, event
      end
      obj
    end
  end

  include InstanceMethods
end

class CommandHandler < BaseObject

  module InstanceMethods
    def handle(command)
      process(command)
      return
    end
  end

  include InstanceMethods

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

class UpdateRecording < Command
  attributes :id, :title, :artist
end

class CreateRecording < Command
  attributes :id, :title, :artist
end

class RecordingCreated < Event
  attributes :id, :title, :artist
end

class RecordingUpdated < Event
  attributes :title, :artist
end

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
    message = "process_" + command.class.name.split(/(?=[A-Z]+)/).map(&:downcase).join("_")
    send message.to_sym, command
  end

  def process_create_recording(command)
    recording = Recording.new(command.to_h)
    RecordingValidator.new(recording: recording).assert_validity
    event = RecordingCreated.new(command.to_h)
    repository.create command.id
    repository.append command.id, event
  end

  def process_update_recording(command)
    recording = repository.find command.id
    attrs = command.to_h
    attrs.delete :id
    recording.set_attributes attrs
    RecordingValidator.new(recording: recording).assert_validity
    event = RecordingUpdated.new(attrs)
    repository.append command.id, event
  end

end

class Recording < Entity
  attributes :id, :title, :artist

end

class CreateRelease < Command
  attributes :id, :title
end

class UpdateRelease < Command
  attributes :id, :title
end

class ReleaseCreated < Event
  attributes :id, :title
end

class ReleaseUpdated < Event
  attributes :title
end

module CrudAggregate

  module ClassMethods
    def repository
      self
    end

    def process(command)
      message = "process_" + command.class.name.split(/(?=[A-Z]+)/).map(&:downcase).join("_")
      send message.to_sym, command
    end
  end

  module InstanceMethods

    def assert_validity
    end
  end

  def self.included(othermod)
    othermod.extend CommandHandler::InstanceMethods
    othermod.extend EventStoreRepository::InstanceMethods
    othermod.extend ClassMethods
    othermod.include InstanceMethods

    othermod.define_singleton_method("type") { othermod }

    othermod.define_singleton_method "process_create_" + othermod.name.split(/(?=[A-Z]+)/).map(&:downcase).join("_") do |command|
      obj = new(command.to_h)
      obj.assert_validity
      event = self.class.const_get("#{othermod.name}Created").new(command.to_h)
      repository.create command.id
      repository.append command.id, event
    end

    othermod.define_singleton_method "process_update_" + othermod.name.split(/(?=[A-Z]+)/).map(&:downcase).join("_") do |command|
      obj = repository.find command.id
      attrs = command.to_h
      attrs.delete :id
      obj.set_attributes attrs
      obj.assert_validity
      event = self.class.const_get("#{othermod.name}Updated").new(attrs)
      repository.append command.id, event
    end

    othermod.define_singleton_method("apply_" + othermod.name.split(/(?=[A-Z]+)/).map(&:downcase).join("_") + "_updated") do |obj, event|
      obj.set_attributes(event.to_h)
    end
  end
end

class Release < Entity
  attributes :id, :title

  include CrudAggregate

end

class RecordingProjection < RecordingRepository

  undef_method :create
  undef_method :append

end

ReleaseProjection = Release

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
    p RecordingProjection.new.find(id)

    id = uuid.()
    command_handler = registry.command_handler_for(Release)
    command = CreateRelease.new(id: id, title: "Test release")
    command_handler.handle command
    command = UpdateRelease.new(id: id, title: "Test release updated")
    command_handler.handle command
    p ReleaseProjection.find id
  end

  private

  attr_reader :uuid
end

Application.new.main
