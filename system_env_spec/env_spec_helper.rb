require "rubygems"
require "bundler/setup"

require 'webmock/rspec'

# We won't load all of rails, but activesupport is helpful
require "active_support"


RSpec.configure do |config|
  # rspec-expectations config goes here. You can use an alternate
  # assertion/expectation library such as wrong or the stdlib/minitest
  # assertions if you prefer.
  config.expect_with :rspec do |expectations|
    # This option will default to `true` in RSpec 4. It makes the `description`
    # and `failure_message` of custom matchers include text for helper methods
    # defined using `chain`, e.g.:
    #     be_bigger_than(2).and_smaller_than(4).description
    #     # => "be bigger than 2 and smaller than 4"
    # ...rather than:
    #     # => "be bigger than 2"
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    # Prevents you from mocking or stubbing a method that does
    # not exist on a real object. This is generally
    # recommended, and will default to `true` in RSpec 4.
    mocks.verify_partial_doubles = true
  end

  # This option will default to `:apply_to_host_groups`
  # in RSpec 4 (and will have no way to turn it off --
  # the option exists only for backwards compatibility
  # in RSpec 3). It causes shared context metadata to
  # be inherited by the metadata hash of host groups
  # and examples, rather than triggering implicit
  # auto-inclusion in groups with matching metadata.
  config.shared_context_metadata_behavior = :apply_to_host_groups

  # This allows you to limit a spec run to individual
  # examples or groups you care about by tagging them with
  # `:focus` metadata. When nothing is tagged with
  # `:focus`, all examples get run. RSpec also provides
  # aliases for `it`, `describe`, and `context` that include
  # `:focus` metadata: `fit`, `fdescribe` and `fcontext`,
  # respectively.
  config.filter_run_when_matching :focus

  # Scihist custom....

  config.default_formatter = 'doc'

  RSpec::Matchers.define :match_version_requirements do |*version_requirements|
    match do |actual_version|
      actual_version.present? && Gem::Requirement.new(*version_requirements).satisfied_by?(
        Gem::Version.new(actual_version)
      )
    end

    failure_message do |actual_version|
      "expected that '#{actual_version}` would match version requirements: #{version_requirements.inspect}"
    end
  end
end
