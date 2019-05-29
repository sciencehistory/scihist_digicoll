require 'rails_helper'

describe WorkResultDisplay do
  RSpec::Matchers.define :include_link_to do |facet_param:,value:|
    match do |actual_array|
      actual_array.any? do |str|
        noko = Nokogiri::HTML.fragment(str)
        noko.children.length == 1 &&
          (element = noko.children[0]) &&
          element.name == "a" &&
          element.text == value &&
          element['href'] == helper.search_on_facet_path(facet_param, value)
      end
    end

    failure_message do |actual|
      "expected that #{actual} would include an <a> tag for #{facet_param}:#{value}"
    end
  end

  let(:parent_work) { create(:work) }

  let(:work) { FactoryBot.create(:work, :with_complete_metadata,
    date_of_work: [Work::DateOfWork.new(start: "2000-01-01", start_qualifier: "circa"), Work::DateOfWork.new(start: "2019-10-10")],
    parent: parent_work,
    source: "Some Source Title",
    genre: ["Advertisements", "Artifacts"],
    additional_title: "An Additional Title",
    subject: ["Subject1", "Subject2"],
    creator: [{category: "contributor", value: "Joe Smith"}, {category: "contributor", value: "Moishe Brown"}, {category: "interviewer", value: "Mary Sue"}]
  )}

  let(:presenter) { described_class.new(work) }
  let(:rendered) { Nokogiri::HTML.fragment(presenter.display) }

  it "displays" do
    work.genre.each do |genre|
      expect(rendered).to have_text(genre)
    end
    expect(rendered).to have_selector("h2 > a", text: work.title)
    expect(rendered).to have_selector("li", text: "An Additional Title")

    expect(rendered).to have_selector("li > a", text: parent_work.title)
    expect(rendered).to have_selector("li > i", text: "Some Source Title")

    expect(rendered).to have_text("Circa 2000-Jan-01")
    expect(rendered).to have_text("2019-Oct-10")

    expect(rendered).to have_selector("a", text: "Subject1")
    expect(rendered).to have_selector("a", text: "Subject2")
    expect(rendered).to have_selector("a", text: "Joe Smith")
    expect(rendered).to have_selector("a", text: "Moishe Brown")
    expect(rendered).to have_selector("a", text: "Mary Sue")
  end

  describe "#metadata_labels_and_values" do
    it "includes subjects" do
      subjects = presenter.metadata_labels_and_values["Subject"]

      expect(subjects).to be_present
      expect(subjects).to be_kind_of(Array)
      expect(subjects.length).to be(2)

      expect(subjects).to include_link_to(value: "Subject1", facet_param: "subject_facet")
      expect(subjects).to include_link_to(value: "Subject2", facet_param: "subject_facet")
    end

    it "separates creators" do
      contributors = presenter.metadata_labels_and_values["Contributor"]
      expect(contributors).to be_present
      expect(contributors).to be_kind_of(Array)
      expect(contributors.length).to be(2)
      expect(contributors).to include_link_to(value: "Joe Smith", facet_param: "creator_facet")
      expect(contributors).to include_link_to(value: "Moishe Brown", facet_param: "creator_facet")


      interviewers = presenter.metadata_labels_and_values["Interviewer"]
      expect(interviewers).to be_present
      expect(interviewers).to be_kind_of(Array)
      expect(interviewers.length).to be(1)
      expect(interviewers).to include_link_to(value: "Mary Sue", facet_param: "creator_facet")
    end
  end
end
