class CrudCommandHandler < CommandHandler

  module InstanceMethods
    private

    def validator(obj)
      raise "Implement in subclass!"
    end

    def repository
      raise "Implement in subclass!"
    end

    def type
      raise "Implement in subclass!"
    end

    def process_create(command)
      obj = type.new(command.to_h)
      validator(obj).assert_validity
      event = self.class.const_get("#{type}Created").new(command.to_h)
      repository.unit_of_work(command.id) do |uow|
        uow.create
        uow.append event
      end
    end

    def process_update(command)
      obj = repository.find command.id
      attrs = command_to_update_attrs(command)
      obj.set_attributes attrs
      validator(obj).assert_validity
      event = self.class.const_get("#{type}Updated").new(attrs)
      repository.unit_of_work(command.id) do |uow|
        uow.append event
      end
    end

    def command_to_update_attrs(command)
      attrs = command.to_h
      attrs.delete :id
      attrs
    end
  end

  include InstanceMethods

end

module CrudAggregate

  module ClassMethods
    def repository
      self
    end

    def validator(obj)
      obj
    end
  end

  module InstanceMethods
    def assert_validity
    end
  end

  def self.included(othermod)
    othermod.extend CommandHandler::InstanceMethods
    othermod.extend CrudCommandHandler::InstanceMethods
    othermod.extend EventStoreRepository::InstanceMethods
    othermod.extend ClassMethods
    othermod.include InstanceMethods

    othermod_name = othermod.name.snake_case

    othermod.define_singleton_method("type") { othermod }

    othermod.define_singleton_method "process_create_#{othermod_name}" do |command|
      process_create command
    end

    othermod.define_singleton_method "process_update_#{othermod_name}" do |command|
      process_update command
    end

    othermod.define_singleton_method("apply_#{othermod_name}_updated") do |obj, event|
      obj.set_attributes(event.to_h)
    end
  end
end