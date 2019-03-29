web: bundle exec puma -C ./deployment/heroku/puma.rb

# Use configuration bellow to run jobs on a separate dyno.
#web: bundle exec puma
#jobs: bundle exec rails runner bin/threaded.rb

###############################
# Multiple DelayedJob workers #
###############################
# Per default ActiveWorkflow can just run one agent at a time. Using a lot of agents or calling slow
# external services frequently might require more DelayedJob workers (an indicator for this is
# a backlog in your 'Job Management' page).
# Every uncommented line starts an additional DelayedJob worker. This works for development, production
# and for the threaded and separate worker processes. Keep in mind one worker needs about 300MB of RAM.
#
#dj2: bundle exec script/delayed_job -i 2 run
#dj3: bundle exec script/delayed_job -i 3 run
#dj4: bundle exec script/delayed_job -i 4 run
#dj5: bundle exec script/delayed_job -i 5 run
#dj6: bundle exec script/delayed_job -i 6 run
#dj7: bundle exec script/delayed_job -i 7 run
#dj8: bundle exec script/delayed_job -i 8 run
#dj9: bundle exec script/delayed_job -i 9 run
#dj10: bundle exec script/delayed_job -i 10 run
