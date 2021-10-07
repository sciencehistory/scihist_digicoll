require 'rails_helper'

describe SearchResult::WorkComponent, type: :component do
  RSpec::Matchers.define :include_link_to do |facet_param:,value:|
    match do |actual_array|
      actual_array.any? do |str|
        noko = Nokogiri::HTML.fragment(str)
        noko.children.length == 1 &&
          (element = noko.children[0]) &&
          element.name == "a" &&
          element.text == value &&
          element['href'] == controller.view_context.search_on_facet_path(facet_param, value)
      end
    end

    failure_message do |actual|
      "expected that #{actual} would include an <a> tag for #{facet_param}:#{value}"
    end
  end

  let(:child_counter) { ChildCountDisplayFetcher.new([work.friendlier_id]) }
  let(:cart_presence) { CartPresence.new([work.friendlier_id], current_user: nil) }

  let(:parent_work) { create(:work) }

  let(:work) { FactoryBot.create(:work, :with_complete_metadata,
    date_of_work: [Work::DateOfWork.new(start: "2000-01-01", start_qualifier: "circa"), Work::DateOfWork.new(start: "2019-10-10")],
    parent: parent_work,
    genre: ["Advertisements", "Artifacts"],
    additional_title: "An Additional Title",
    subject: ["Subject1", "Subject2"],
    creator: [{category: "contributor", value: "Joe Smith"}, {category: "contributor", value: "Moishe Brown"}, {category: "interviewer", value: "Mary Sue"}],
    members: [create(:asset), create(:asset)]
  )}

  let(:presenter) { described_class.new(work, child_counter: child_counter, cart_presence: cart_presence) }
  let(:rendered) { render_inline(presenter) }

  it "displays" do
    work.genre.each do |genre|
      expect(rendered).to have_text(genre)
    end
    expect(rendered).to have_selector("h2 > a", text: work.title)
    expect(rendered).to have_selector("li", text: "An Additional Title")

    expect(rendered).to have_selector("li > a", text: parent_work.title)

    expect(rendered).to have_text("Circa 2000-Jan-01")
    expect(rendered).to have_text("2019-Oct-10")

    expect(rendered).to have_selector("a", text: "Subject1")
    expect(rendered).to have_selector("a", text: "Subject2")
    expect(rendered).to have_selector("a", text: "Joe Smith")
    expect(rendered).to have_selector("a", text: "Moishe Brown")
    expect(rendered).to have_selector("a", text: "Mary Sue")

    expect(rendered).to have_content("2 items")
  end

  describe "one child" do
    let(:work) { create(:work, members: [create(:asset)])}

    it "does not display num items" do
      expect(rendered).not_to have_content("1 item")
      expect(rendered).not_to have_content("item")
    end
  end

  describe "#metadata_labels_and_values" do
    before do
      rendered # trigger so we can get to methods to test em.
    end

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
