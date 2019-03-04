require 'rails_helper'

class ProgressBarStub
  def log()
  end
  def increment()
  end
end

class GenericWorkImporter
  def initialize()
    @@progress_bar = ProgressBarStub.new()
  end
end

RSpec.describe Importers::GenericWorkImporter do
  context "Import work" do
    context "simple work" do
      let(:generic_work_importer) { FactoryBot.create(:generic_work_importer)}
      before do
        allow(generic_work_importer).to receive(:read_from_file).and_return(nil)
        allow(generic_work_importer).to receive(:report_via_progress_bar).and_return(nil)
      end

      it "Imports properly" do
        generic_work_importer.save_item()
        expect(Work.first.title).to match /Adulterations/
      end
    end
  end
end
