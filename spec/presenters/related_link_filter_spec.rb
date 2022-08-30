require 'rails_helper'

describe RelatedLinkFilter do
  let(:related_work_links) {[
    RelatedLink.new(category: "related_work", url: "http://digital.sciencehistory.org/works/work1"),
    RelatedLink.new(category: "related_work", url: "https://digital.sciencehistory.org/works/work2")
  ]}
  let(:general_links) {[
    RelatedLink.new(category: "distillations_article", url:"http://example.org/foo"),
    RelatedLink.new(category: "institute_blog_post", url: "https://example.org/bar")
  ]}
  let(:finding_aid_links) {[
    RelatedLink.new(category: "finding_aid", url:"http://archives.sciencehistory.org/foo"),
    RelatedLink.new(category: "finding_aid", url: "https://archives.sciencehistory.org/bar")
  ]}

  let(:all_urls) { related_work_links + general_links + finding_aid_links }

  let(:filter) { RelatedLinkFilter.new(all_urls) }

  it "filters" do
    expect(filter.general_related_links).to eq(general_links)
    expect(filter.finding_aid_related_links).to eq(finding_aid_links)
  end

  it "extracts related_work_friendlier_ids" do
    expect(filter.related_work_friendlier_ids).to eq(["work1", "work2"])
  end

  describe "nil input" do
    let(:filter) { RelatedLinkFilter.new(nil) }

    it "has empty output" do
      expect(filter.general_related_links).to eq []
      expect(filter.finding_aid_related_links).to eq []
      expect(filter.related_work_friendlier_ids).to eq []
    end
  end
end
