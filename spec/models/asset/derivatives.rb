require 'rails_helper'

describe "audio derivative creation" do

  let(:test_file_path) { Rails.root.join("spec/test_support/audio/ice_cubes.mp3")}
  let(:test_file_sha512) { Digest::SHA512.hexdigest(File.read(test_file_path)) }
  let!(:asset) { FactoryBot.create(:asset, file: File.open(test_file_path)) }

  it "creates audio derivatives for mp3 and webm" do
    # The derivative creation process expects the file object
    # to have persisted sha512 data on the UploadedFile.
    asset.file.metadata['sha512'] = test_file_sha512
    asset.save!
    asset.create_derivatives

    mp3_deriv  = asset.derivatives.find { |x| x.key == 'mp3'  }
    webm_deriv = asset.derivatives.find { |x| x.key == 'webm' }
    expect(mp3_deriv).not_to be_nil
    expect(webm_deriv).not_to be_nil
    expect(mp3_deriv.file_data['id']).to match(/mp3$/)
    expect(mp3_deriv.file_data['metadata']['mime_type']).to eq('audio/mpeg')
    expect(mp3_deriv.file_data['metadata']['kithe_derivative_key']).to eq('mp3')
    expect(webm_deriv.file_data['id']).to match(/webm$/)
    expect(webm_deriv.file_data['metadata']['mime_type']).to match(/webm$/)
    expect(webm_deriv.file_data['metadata']['kithe_derivative_key']).to eq('webm')
  end
end
