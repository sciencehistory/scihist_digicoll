require 'rails_helper'

describe "derivative creation" do

  let(:audio_file_path) { Rails.root.join("spec/test_support/audio/ice_cubes.mp3")}
  let(:audio_file_sha512) { Digest::SHA512.hexdigest(File.read(audio_file_path)) }
  let!(:audio_asset) { FactoryBot.create(:asset, file: File.open(audio_file_path)) }

  let(:pdf_file_path) { Rails.root.join("spec/test_support/pdf/sample.pdf")}
  let(:pdf_file_sha512) { Digest::SHA512.hexdigest(File.read(pdf_file_path)) }
  let!(:pdf_asset) { FactoryBot.create(:asset, file: File.open(pdf_file_path)) }


  it "creates audio derivatives" do
    # The derivative creation process expects the file object
    # to have persisted sha512 data on the UploadedFile.
    audio_asset.file.metadata['sha512'] = audio_file_sha512
    audio_asset.save!
    audio_asset.create_derivatives

    mp3_deriv  = audio_asset.derivatives.find { |x| x.key == 'mp3'  }
    webm_deriv = audio_asset.derivatives.find { |x| x.key == 'webm' }
    expect(mp3_deriv).not_to be_nil
    expect(webm_deriv).not_to be_nil
    expect(mp3_deriv.file_data['id']).to match(/mp3$/)
    expect(mp3_deriv.file_data['metadata']['mime_type']).to eq('audio/mpeg')
    expect(mp3_deriv.file_data['metadata']['kithe_derivative_key']).to eq('mp3')
    expect(webm_deriv.file_data['id']).to match(/webm$/)
    expect(webm_deriv.file_data['metadata']['mime_type']).to match(/webm$/)
    expect(webm_deriv.file_data['metadata']['kithe_derivative_key']).to eq('webm')
  end

  it "creates pdf derivatives" do
    pdf_asset.file.metadata['sha512'] = pdf_file_sha512
    pdf_asset.save!
    pdf_asset.create_derivatives
    expect(pdf_asset.derivatives.pluck('key').sort).
      to contain_exactly("thumb_large","thumb_large_2X",
        "thumb_mini", "thumb_mini_2X",
        "thumb_standard", "thumb_standard_2X"
      )
    widths = Hash[pdf_asset.derivatives.
      collect { |d| [d.key.to_sym, d.file_data['metadata']['width']] }]

    expect(widths[:thumb_mini]).to eq(54)
    expect(widths[:thumb_large_2X]).to eq(1050)
  end




end
