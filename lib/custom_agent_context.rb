# This class is passed as a parameter to the custom agent and is used to
# communicate with the system. This is accomplished by delegating method calls
# to the backing agent object (target).
class CustomAgentContext
  attr_reader :target

  def initialize(target)
    @target = target
  end

  def options
    target.options
  end

  def memory
    target.memory
  end

  def memory=(data)
    target.memory = data
  end

  def log(data)
    target.log(data)
  end

  def error(data)
    target.error(data)
  end

  def emit_message(payload)
    target.create_message(payload: payload)
  end

  def credential(name)
    target.credential(name)
  end
end

