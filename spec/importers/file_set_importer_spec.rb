require 'rails_helper'

class ProgressBarStub
  def log()
  end
  def increment()
  end
end

class Importers::FileSetImporter
  def initialize()
    @@progress_bar = ProgressBarStub.new()
  end
  # "populate()" attempts to actually download
  # a file from Fedora and generate derivatives;
  # this is out of scope for this test.
  def populate()
    super
  end
end

RSpec.describe Importers::FileSetImporter do
  context "Import fileset" do
    context "simple fileset" do
      let(:file_set_importer) { FactoryBot.create(:file_set_importer)}
      before do
        allow(file_set_importer).to receive(:read_from_file).and_return(nil)
        allow(file_set_importer).to receive(:report_via_progress_bar).and_return(nil)
      end

      it "Imports properly" do
        file_set_importer.save_item()
        expect(Asset.first.title).to match /b10371138_367/
      end
    end
  end
end
