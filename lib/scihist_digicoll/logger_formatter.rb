
module ScihistDigicoll
  # custom sub-class to log a bit less than ruby standard logger formatter.
  #
  # * We don't need timestamp because heroku is going to add it
  # * We don't need the log level reported two different ways
  # * We don't need the process # ($$), doesn't do anything we care about on heroku.
  # * We don't need progname, it seems to weirdly be empty r just a colon
  #
  # Which actually leaves nothing but severity... maybe we don't even really need
  # that? But it's convenient to be able to search for just FAIL or WARN, so we'll
  # leave it. (Papertrail thinks it knows severity out of band, but it dooesn't, on
  # heroku it thinks everything is 'INFO')
  #
  # You can see original at eg https://github.com/ruby/ruby/blob/v2_7_4/lib/logger/formatter.rb
  class LoggerFormatter < ::Logger::Formatter
    def call(severity, time, progname, msg)
      # could be `severity[0..0]` if we only wanted eg `I` or `W`, but I like `INFO` or `WARN` for
      # easier visibility/grep-ability.
      "%s: %s\n" % [severity, msg2str(msg)]
    end
  end
end
