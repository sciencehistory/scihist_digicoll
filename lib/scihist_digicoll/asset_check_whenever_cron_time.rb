module ScihistDigicoll
  # In a constnat used in our whenever cron schedule, that can also be used
  # in text describing fixity configuration to staff.
  #
  # Whenever 'schedule.rb' does not load rails, so we need to put this
  # in a file in lib that we can load
  ASSET_CHECK_WHENEVER_CRON_TIME = '2:30 am'
end
