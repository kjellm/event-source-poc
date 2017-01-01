module CrudAggregate

  module ClassMethods
    def repository
      self
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

    othermod_name = othermod.name.snake_case

    othermod.define_singleton_method("type") { othermod }

    othermod.define_singleton_method "process_create_" + othermod_name do |command|
      obj = new(command.to_h)
      obj.assert_validity
      event = self.class.const_get("#{othermod.name}Created").new(command.to_h)
      repository.unit_of_work(command.id) do |uow|
        uow.create
        uow.append event
      end
    end

    othermod.define_singleton_method "process_update_" + othermod_name do |command|
      obj = repository.find command.id
      attrs = command.to_h
      attrs.delete :id
      obj.set_attributes attrs
      obj.assert_validity
      event = self.class.const_get("#{othermod.name}Updated").new(attrs)
      repository.unit_of_work(command.id) do |uow|
        uow.append event
      end
    end

    othermod.define_singleton_method("apply_" + othermod_name + "_updated") do |obj, event|
      obj.set_attributes(event.to_h)
    end
  end
end
