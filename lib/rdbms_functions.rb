module RDBMSFunctions
  def rdbms_date_add(source, unit, amount)
    adapter_type = ActiveRecord::Base.connection.adapter_name.downcase.to_sym
    case adapter_type
    when :postgresql
      "(#{source} + INTERVAL '#{amount} #{unit}')"
    when :sqlite
      "(datetime(#{source}, '+#{amount} #{unit.downcase}'))"
    else
      raise NotImplementedError, "Unknown adapter type '#{adapter_type}'"
    end
  end
end
