require 'open3'

class ActiveWorkflowAgent
  class Helper
    def self.open3(command)
      output = ""

      status = Open3.popen3(ENV, "#{command} 2>&1") do |stdin, stdout, _stderr, wait_thr|
        stdin.close

        until stdout.eof do
          next unless IO.select([stdout])
          output << stdout.read_nonblock(1024)
        end
        wait_thr.value
      end
      [status.exitstatus, output]
    rescue IOError => e
      return [1, "#{e} #{e.message}"]
    end

    def self.exec(command)
      print "\n"
      [system(ENV, command) == true ? 0 : 1, '']
    end
  end
end
