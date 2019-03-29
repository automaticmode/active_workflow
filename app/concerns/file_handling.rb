require 'base64'

module FileHandling
  extend ActiveSupport::Concern

  def get_file_pointer(file)
    { file_pointer: { file: file, agent_id: id } }
  end

  def has_file_pointer?(message)
    message.payload['file_pointer'] &&
      message.payload['file_pointer']['file'] &&
      message.payload['file_pointer']['agent_id']
  end

  def get_io(message)
    return nil unless has_file_pointer?(message)

    return embedded_io(message) if message.payload['file_pointer']['body']

    message.user.agents.find(message.payload['file_pointer']['agent_id']).get_io(message.payload['file_pointer']['file'])
  end

  def get_upload_io(message)
    filename = message.payload['file_pointer']['filename'] || 'local.path'
    mime_type = MIME::Types.type_for(File.basename(filename)).first.try(:content_type) || 'text/plain'
    Faraday::UploadIO.new(get_io(message), mime_type, filename)
  end

  def emitting_file_handling_agent_description
    @emitting_file_handling_agent_description ||=
      "This agent only emits a 'file pointer', not the data inside the files, the following agents can consume the created messages: `#{receiving_file_handling_agents.join('`, `')}`."
  end

  def receiving_file_handling_agent_description
    @receiving_file_handling_agent_description ||=
      "This agent can consume a 'file pointer' message from the following agents with no additional configuration: `#{emitting_file_handling_agents.join('`, `')}`."
  end

  private

  def embedded_io(message)
    StringIO.new(Base64.decode64(message.payload['file_pointer']['body']))
  end

  def emitting_file_handling_agents
    emitting_file_handling_agents = file_handling_agents.select(&:emits_file_pointer?)
    emitting_file_handling_agents.map { |a| a.to_s.demodulize }
  end

  def receiving_file_handling_agents
    receiving_file_handling_agents = file_handling_agents.select(&:consumes_file_pointer?)
    receiving_file_handling_agents.map { |a| a.to_s.demodulize }
  end

  def file_handling_agents
    @file_handling_agents ||= Agent.types.select { |c| c.included_modules.include?(FileHandling) }.map { |d| d.name.constantize }
  end

  module ClassMethods
    def emits_file_pointer!
      @emits_file_pointer = true
    end

    def emits_file_pointer?
      !!@emits_file_pointer
    end

    def consumes_file_pointer!
      @consumes_file_pointer = true
    end

    def consumes_file_pointer?
      !!@consumes_file_pointer
    end
  end
end
