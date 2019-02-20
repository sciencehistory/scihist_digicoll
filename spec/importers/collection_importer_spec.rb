require 'rails_helper'

class ProgressBarStub
  def log()
  end
  def increment()
  end
end

class Importer
  def initialize()
    @@progress_bar = ProgressBarStub.new()
  end
end

RSpec.describe CollectionImporter do
  context "Import collection" do
    context "simple collection" do
      let(:collection_importer) { FactoryBot.create(:collection_importer)}
      before do
        allow(collection_importer).to receive(:read_from_file).and_return(nil)
        allow(collection_importer).to receive(:report_via_progress_bar).and_return(nil)
      end

      it "Imports properly" do
        collection_importer.save_item()
        expect(Collection.first.title).to match /Pesticide Collection/
      end
    end
  end
end
