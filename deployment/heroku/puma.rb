workers Integer(ENV['WEB_CONCURRENCY'] || 2)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

preload_app!

rackup      DefaultRackup
port        ENV['PORT'] || 3000

environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  ActiveRecord::Base.establish_connection
end

# Note that this will only work correctly when running Heroku with ONE web worker.
# If you want to run more than one, use the standard ActiveWorkflow Procfile instead, with separate web and job entries.
# You'll need to set the Heroku config variable PROCFILE_PATH to 'Procfile'.
Thread.new do
  worker_pid = nil
  while true
    if worker_pid.nil?
      worker_pid = spawn('bundle exec rails runner bin/threaded.rb')
      puts "New threaded worker PID: #{worker_pid}"
    end

    sleep 45

    begin
      Process.getpgid worker_pid
    rescue Errno::ESRCH
      # No longer running
      worker_pid = nil
    end
  end
end
