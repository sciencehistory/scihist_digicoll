class ApplicationComponent < ViewComponent::Base
  delegate :can?, to: :helpers
end
