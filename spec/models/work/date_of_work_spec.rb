require 'rails_helper'

describe Work::DateOfWork, type: :model do
  context "validation" do
    it "requires present start date if qualifier" do
      model = Work::DateOfWork.new(start_qualifier: 'after')
      expect(model.valid?).to be(false)
      expect(model.errors.find {|i| i == [:start,  "must be of format YYYY[-MM-DD]"]}).to be_present
    end

    it "requires well-formed start date" do
      model = Work::DateOfWork.new(start: 'bad date')
      expect(model.valid?).to be(false)
      expect(model.errors.find {|i| i == [:start,  "must be of format YYYY[-MM-DD]"]}).to be_present
    end

    it "requires start date to be blank if undated qualifier" do
      model = Work::DateOfWork.new(start_qualifier: 'undated', start: "1990-01-01")
      expect(model.valid?).to be(false)
      expect(model.errors.find {|i| i == [:start,  "should be left blank if you specify 'undated'."]}).to be_present
    end
  end
end
