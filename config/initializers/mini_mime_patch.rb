# minimime doesn't have a good API for adding mappings, let's do it with a patch

# missing mapping for audio/opus, we actually want to map it to .oga just like
# audio/ogg -- some map it to `.opus` but there is confusion over whether
# that should mean raw non-OGG opus audio bitstream instead?
#
# Without this patch lookup_by_content_type("audio/opus") is just nil
#
# This makes kithe use the .oga extension for audio/opus derivatives

MiniMime.singleton_class.prepend(Module.new do
  def lookup_by_content_type(content_type, ...)
    super || (MiniMime.lookup_by_content_type("audio/ogg") if content_type == "audio/opus")
  end
end)
