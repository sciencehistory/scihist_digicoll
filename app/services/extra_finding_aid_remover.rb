# Invoked by:
# See https://github.com/sciencehistory/scihist_digicoll/pull/2726 for context.
# lib/tasks/remove_extra_finding_aids.rake
# We're leaving both the rake task and the service class around - it's likely enough that we will have to run this helper (or something very similar to it) in the future.
# We are going to remove the test from the repo, though, as we don't really need it slowing down our tests.
class ExtraFindingAidRemover
  attr_reader :work

  def initialize(work, dry_run:false)
    @work = work
    @dry_run = dry_run
    @notes = []
  end

  def process
    return unless current_related_links.present?
    return unless current_related_links.map { |rl| rl.category }.include? 'finding_aid'
    return if current_related_links == new_related_links

    @work.update!(related_link: new_related_links) unless @dry_run

    @notes << "#{ @work.friendlier_id.ljust(10) } before: #{current_related_links.to_a}"
    @notes << "#{ @work.friendlier_id.ljust(10) } after:  #{new_related_links.to_a}"
  end


  def notes
    @notes
  end

  private

  def current_related_links
    @current_related_links ||= Set.new(@work.related_link)
  end

  def new_related_links
    @new_related_links ||= Set.new(
      current_related_links.reject do |rl|
        rl.category == "finding_aid" &&
        finding_aid_urls_from_other_sources.include?(rl.url)
      end
    )
  end

  def other_models_to_check
    [ @work.parent, @work.contained_by, @work.parent&.contained_by ].flatten.compact
  end

  def finding_aid_urls_from_other_sources
    @finding_aid_urls_from_other_sources ||= other_models_to_check.map do |mod|
      mod.related_link.select { |rl| rl.category == "finding_aid" }.map &:url
    end.flatten.uniq
  end

end
