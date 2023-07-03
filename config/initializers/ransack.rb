Ransack.configure do |c|
  # Raise errors if a query contains an unknown predicate or attribute.
  # Default is true (do not raise error on unknown conditions).
  #
  # we TRY to raise on a non-allowed atribute in development or test envs, so we
  # can catch that we forgot to list them!
  #
  # However, ransack does not actually raise when we are SORTING on an unlisted
  # properly, so we can still easily miss those. Better than nothing.
  # https://github.com/activerecord-hackery/ransack/issues/1427
  #
  c.ignore_unknown_conditions = Rails.env.production?
end
