require 'rails_helper'

describe DateDisplayFormatter, type: :model do
  describe "individual dates" do
    # Test cases ported from
    # https://github.com/sciencehistory/chf-sufia/blob/master/spec/presenters/curation_concerns/generic_work_show_presenter_spec.rb#L47
    # https://github.com/sciencehistory/chf-sufia/blob/master/spec/presenters/curation_concerns/generic_work_show_presenter_spec.rb#L155-L199
    {
      Work::DateOfWork.new(start: "1800") => "1800",
      Work::DateOfWork.new => "",
      Work::DateOfWork.new(note: "circa") => " (circa)",
      Work::DateOfWork.new(start: "1912", start_qualifier: "decade") => "Decade starting 1912",
      Work::DateOfWork.new(start: "1780", start_qualifier: "decade") => "1780s",
      Work::DateOfWork.new(start: "way back when", start_qualifier: "decade") => "Decade starting way back when",
      Work::DateOfWork.new(start: "1912", start_qualifier: "century") => "Century starting 1912",
      Work::DateOfWork.new(start: "1780", start_qualifier: "century") => "Century starting 1780",
      Work::DateOfWork.new(start: "way back when", start_qualifier: "century") => "Century starting way back when",
      Work::DateOfWork.new(start: "1700", start_qualifier: "century") => "1700s",
      Work::DateOfWork.new(start: "the end of time", start_qualifier: "after", note: "For real!") => "After the end of time (For real!)",
      Work::DateOfWork.new(start: "the end of time", start_qualifier: "circa") => "Circa the end of time",
      Work::DateOfWork.new(start: "1800", finish: "1900", start_qualifier: "century", note: "Note 1") => "1800s – 1900 (Note 1)",
      Work::DateOfWork.new(start: "1800", finish: "1900", start_qualifier: "century", note: "Note 2") => "1800s – 1900 (Note 2)",
      Work::DateOfWork.new(start: "1929-01-02", finish: "1929-01-03", start_qualifier: "circa", finish_qualifier: "before", note: "Note 3") => "Circa 1929-Jan-02 – before 1929-Jan-03 (Note 3)",
      Work::DateOfWork.new(start: "1872", finish: "1929-01-03", start_qualifier: "after", finish_qualifier: "before", note: "Note 4") => "After 1872 – before 1929-Jan-03 (Note 4)",
      Work::DateOfWork.new(start: "1920", finish: "1928-11", start_qualifier: "decade", note: "Note 5") => "1920s – 1928-Nov (Note 5)",
      Work::DateOfWork.new(start: "1", finish: "200") => "1 – 200",
      Work::DateOfWork.new(start: "1900-13") => "1900-13",
      Work::DateOfWork.new(start_qualifier: "undated") => "Undated"
    }.each do |input, output|
      it "should format '#{input.to_json}' as #{output.inspect}" do
        expect(DateDisplayFormatter.new([input]).display_dates).to eq([output])
      end
    end
  end

  describe "array of dates" do
    let(:date_array) {[
      Work::DateOfWork.new(start: "1912", start_qualifier: "century"),
      Work::DateOfWork.new(start: "1800"),
      Work::DateOfWork.new,
      Work::DateOfWork.new(start: "1800", finish: "1900")
    ]}

    it "formats them all in order" do
      # should it sort them? It doesn't yet...
      expect(DateDisplayFormatter.new(date_array).display_dates).to eq(
        date_array.
          sort_by {|d| d.start || "0" }.
          collect { |d| DateDisplayFormatter.new([d]).display_dates}.
          flatten
      )
    end
  end
end
