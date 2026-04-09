module OhmsHelper
  # seconds in, hh:mm::ss out. Including 0 for hours.
  def format_ohms_timestamp(duration_seconds)
    # duration in seconds modulus number of seconds in one minute
    seconds = (duration_seconds / 1.second) % (1.minute / 1.second)

    # duration in minutes modulus number of minutes in one hour
    minutes = (duration_seconds / 1.minute) % (1.hour / 1.minute)

    # duration in hours modulus number of hours in one day
    hours = (duration_seconds / 1.hour) % (1.day / 1.hour)

    "#{'%02d' % hours}:#{'%02d' % minutes}:#{'%02d' % seconds}"
  end

  # in is "hh:mm:ss", out is seconds integer
  def parse_ohms_timestamp(timestamp_str)
    unless timestamp_str =~ /\A(\d{2,}):(\d\d):(\d\d)\Z/
      raise ArgumentError.new("timestamp str must match \d\d:\d\d:\d\d,not #{timestamp_str}")
    end

    hours, minutes, seconds = $1.to_i, $2.to_i, $3.to_i

    return (hours * 60 * 60) + (minutes * 60) + seconds
  end

  # make methods availble as static/module methods too
  extend self
end
