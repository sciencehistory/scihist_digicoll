# Tries to parse the user-agent to make a much more compact representation of what we'd
# eally want to know from it, to keep our logs shorter
#
# Currently implemented with device_detector gem.

class CompactUserAgent
  attr_reader :user_agent

  def initialize(user_agent)
    @user_agent = user_agent
  end

  def compact
    @compact ||= [
      bot,
      application,
      os,
      device
    ].collect(&:presence).compact.join("/").yield_self do |str|
      if str.presence == nil
        # if we couldn't parse, give em first 15 chars of thing, no spaces.
        user_agent&.slice(0, 50)&.gsub(" ", "_")
      else
        str.gsub(" ", "_")
      end
    end
  end


  private

  # empty, or eg `"bot:GoogleBot"
  def bot
    "bot:#{device_detector.bot_name&.gsub(' ', '_')}" if device_detector.bot?
  end

  # Can be empty, otherwise something like "Chrome-13" or just "Chrome"
  def application
    [
      device_detector.name,
      device_detector.full_version&.split(".")&.first&.presence
    ].compact.join("-")
  end

  # Can be empty, otherwise something like "Android-6.3" or just "Android"
  def os
    [
      device_detector.os_name,
      device_detector.os_full_version&.split(".")&.slice(0,2)&.join(".")
    ].compact.join("-")
  end

  # Can be empty, otherwise someting like "Nexus 5X"
  def device
    device_detector.device_name
  end

  def device_detector
    # Device_detector isn't good with nil but is fine with empty string
    # https://github.com/podigee/device_detector/blob/develop/CHANGELOG.md
    @device_detector ||= DeviceDetector.new(user_agent || "")
  end

end
