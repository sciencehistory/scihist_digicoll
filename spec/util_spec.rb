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

  describe "#simple_bytes_to_human_string" do
    it "has correct units with no zero after decimal" do
      expect(ScihistDigicoll::Util.simple_bytes_to_human_string(1024)).to eq("1 KB")
    end

    it "has correct units with decimals" do
      expect(ScihistDigicoll::Util.simple_bytes_to_human_string(1124)).to eq("1.1 KB")
      expect(ScihistDigicoll::Util.simple_bytes_to_human_string(98343434)).to eq("93.8 MB")
      expect(ScihistDigicoll::Util.simple_bytes_to_human_string(2.48 * 1024 * 1024 * 1024)).to eq("2.5 GB")
    end

    it "has no decimal if three whole digits even if there is remainder" do
      expect(ScihistDigicoll::Util.simple_bytes_to_human_string((200 * 1024) + 110)).to eq("200 KB") # not 200.1 KB
    end
  end
end
