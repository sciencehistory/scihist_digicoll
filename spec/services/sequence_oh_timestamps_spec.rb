require 'docx'
require 'rails_helper'

describe SequenceOhTimestamps do
  # Extracts  `[00:01:23]`, split into sections separated by `[END OF AUDIO, ..]` markers.
  # In form of hash keyed by index of section.
  # Useful for seeing if the timecodes were changed properly!
  def tokens_of_interest(str)
    tokens = str.scan(/(\[\d\d:\d\d:\d\d\])|(\[END OF AUDIO, FILE [^\]]+\])/).flatten.compact

    section_i = 0

    # split into separate sections split by 'END OF FILE' markers, in
    # hash keyed by index of section.
    tokens.group_by do |token|
      if token =~ /\[END OF AUDIO, FILE [^\]]+\]/
        section_i += 1
        nil
      else
        section_i
      end
    end.tap { |hash| hash.delete(nil) }
  end

  # hh:mm:ss(.fff) to integer/float num seconds.
  def timestamp_to_sec(str)
    if str =~ /\[(\d+):(\d\d):(\d\d)(?:\.(\d+))?\]/
      hours, minutes, seconds, fractional_seconds = $1.to_i, $2.to_i, $3.to_i, $4.to_f
      timecode_seconds = seconds + (minutes * 60) + (hours * 60 * 60)

      if fractional_seconds != 0
        timecode_seconds = timecode_seconds + fractional_seconds
      end

      return timecode_seconds
    end
  end

  let(:start_times) {
    { 1 => 0, 2=> 60*60*2, 3=> 7927 }
  }
  let(:path) { Rails.root + "spec/test_support/oh_docx/sample-oh-timecode-need-sequencing.docx" }
  let(:service) { described_class.new(File.open(path), start_times) }


  # This was hard to figure out how to write a test for, sorry this is a bit
  # convoluted and mathematical!
  it "uses arithmetic to fix timecodes to sequence" do
    out_file = service.process

    orig = Docx::Document.open(path.to_s)
    orig_tokens = tokens_of_interest(orig.text)

    sequenced = Docx::Document.open(out_file)
    sequenced_tokens = tokens_of_interest(sequenced.text)

    start_times.each_pair do |section_num, offset|
      expect(sequenced_tokens[section_num - 1]).to eq(
        orig_tokens[section_num - 1].collect do |timecode|
          "[" + OhmsHelper.format_ohms_timestamp(
            timestamp_to_sec(timecode) + offset
          ) + "]"
        end
      )
    end
  end

  describe "with more start_times transript markers" do
    let(:start_times) {
      { 1 => 0, 2 => 60*60*2, 3=>7927, 4=> 10000 }
    }

    it "raises" do
      expect {
        out_file = service.process
      }.to raise_error(SequenceOhTimestamps::InputError) do |error|
        expect(error.message).to match /3 markers in transcript/
        expect(error.message).to match /4 values in file_start_times/
      end
    end
  end

  describe "with fewer start_times transript markers" do
    let(:start_times) {
      { 1 => 0, 2 => 60*60*2 }
    }

    it "raises" do
      expect {
        out_file = service.process
      }.to raise_error(SequenceOhTimestamps::InputError) do |error|
        expect(error.message).to match /3 markers in transcript/
        expect(error.message).to match /2 values in file_start_times/
      end
    end
  end

  describe "with bad file" do
    let(:path) { Rails.root + "spec/test_support/images/20x20.png" }

    it "raises appropriate error" do
      expect {
        service.process
      }.to raise_error(SequenceOhTimestamps::InputError)
    end
  end
end
