class ApplicationComponent < ViewComponent::Base
  # Would be nice to have this `delegate` in our subclasses rather than here,
  # but doing that causes it to raise an `undefined method` error.
  delegate :can?, to: :helpers
end
