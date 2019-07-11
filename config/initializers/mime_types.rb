# Be sure to restart your server when you modify this file.

# Add new mime types for use in respond_to blocks:
# Mime::Type.register "text/richtext", :rtf
#
Mime::Type.register 'application/x-endnote-refer', :endnote

Mime::Type.register "application/x-research-info-systems", :ris
Mime::Type.register "application/vnd.citationstyles.csl+json", :csl

# We want mp3 not mpga
Mime::Type.register "audio/mpeg", :mp3

# Oddly, audio/flac isn't registered with IANA (and thus isn't available in many automated
# databases), but other software often uses it anyway.
Mime::Type.register "audio/flac",   :flac
Mime::Type.register "audio/x-flac", :flac
