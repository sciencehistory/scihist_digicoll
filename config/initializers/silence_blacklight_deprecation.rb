# This silences ALL deprecation warnings from Blacklight, and anything else that uses the
# "deprecation" gem -- currently, in our app looks like just the "qa" gem.
#
# This is not ideal, but we couldn't find a way to avoid deprecation warnings when
# upgrading to BL 7.19.2, and we need to keep them from cluttering up our logs.
#
# We do wrap in sane_patch for extra self-documenting/alerting, although just
# for Blaclight not for `qa`, sorry.
#
# TBD: link to blog post with background

details = <<-EOS
We had to silence Blacklight 7.x deprecation messages that we were unable to
avoid. But before upgrading to Blacklight 8.0, you'll have to deal with this,
one way or another. You may want to re-enable deprecation warnings while
still in BL 7.x to see what you're in for.
EOS

SanePatch.patch('blacklight', '~> 7.0', details: details ) do
  Deprecation.default_deprecation_behavior = :silence
end
