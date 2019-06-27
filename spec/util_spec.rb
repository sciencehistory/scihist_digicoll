require 'rails_helper'

describe ScihistDigicoll::Util do
  describe "#humanized_content_type" do
    it "translates a registered one" do
      expect(ScihistDigicoll::Util.humanized_content_type("application/pdf")).to eq("PDF")
    end

    it "passes through an unknown one" do
      expect(ScihistDigicoll::Util.humanized_content_type("application/x-made-up")).to eq("application/x-made-up")
    end
  end

end
