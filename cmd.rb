module Validations

  def required(*values)
    values.none?(&:nil?) or
      raise ArgumentError
  end

  def non_blank_string(obj)
    return unless obj
    obj.is_a?(String) && !obj.strip.empty? or
      raise ArgumentError
  end

  def positive_integer(obj)
    return unless obj
    obj.is_a?(Integer) && obj > 0 or
      raise ArgumentError
  end

end

class Command < ValueObject

  include Validations

  def initialize(*args)
    super
    validate
  end

  def validate
    raise "Implement in subclass! #{self.class.name}"
  end

end

class CommandHandler < BaseObject

  module InstanceMethods
    def handle(command)
      process(command)
      return
    end

    def process(command)
      message = "process_" + command.class.name.snake_case
      send message.to_sym, command
    end
  end

  include InstanceMethods

end

class CommandHandlerLoggDecorator < DelegateClass(CommandHandler)

  def initialize(obj)
    super obj
  end

  def handle(command)
    logg "Start handling: #{command.inspect}"
    super
  ensure
    logg "Done handling: #{command.class.name}"
  end

end
