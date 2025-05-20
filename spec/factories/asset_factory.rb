FactoryBot.define do

  # Most of the derivatives stuff was written with kithe 1, it ought to actually be
  # able to simplify a lot with kithe 2, but haven't fully yet.

  factory :asset, class: Asset do
    title { 'Test title' }
    published { true }

    # This will take a real file and send it through the real logic
    # for extracting metadata and creating derivatives -- but make sure to do it
    # inline instead of in bg ActiveJobs.
    #
    # You will have to actually save the Asset to have everything there, won't
    # work with `build` strategy.
    #
    # Gives you a real file synchronously, but takes some time.
    #
    # Will use a default small png, but you can pass `file:` with whatever file you want,
    # of any media type.
    trait :inline_promoted_file do
      file { File.open((Rails.root + "spec/test_support/images/30x30.png")) }
      after(:build) do |asset|
        asset.file_attacher.set_promotion_directives(promote: :inline, create_derivatives: :inline)
      end
    end

    trait :bg_derivatives do
      after(:build) do |asset|
        asset.file_attacher.set_promotion_directives(create_derivatives: :background)
      end
    end

    trait :no_derivatives_creation do
      after(:build) do |asset|
        asset.file_attacher.set_promotion_directives(create_derivatives: false)
      end
    end

    # Will not trigger promotion phase, which also means no derivatives.
    trait :non_promoted_file do
      file { File.open((Rails.root + "spec/test_support/images/30x30.png")) }
      after(:build) do |asset|
        asset.file_attacher.set_promotion_directives(promote: false)
      end
    end

    trait :suppress_ocr do
      suppress_ocr { true }
      ocr_admin_note { "No text on this page, so no need for OCR."}
    end

    trait :with_ocr do
      hocr { ($sample_hocr_for_factory ||= File.read('spec/test_support/hocr_xml/hocr.xml')) }

      after(:build) do |asset|
        asset.file_attacher.merge_derivatives({
          # okay not really a textonly pdf, just a fake tiny blank pdf
          textonly_pdf: create(:stored_uploaded_file,
            content_type: "application/pdf",
            file: File.open((Rails.root + "spec/test_support/pdf/tiny.pdf")))
        })
      end
    end

    trait :fake_dzi do
      after(:build) do |asset, evaluator|
        asset.dzi_manifest_file_attacher.set(Shrine::UploadedFile.new(id: "faked", storage: DziPackage::DEFAULT_SHRINE_STORAGE_KEY.to_s))
      end
    end

    # While it still uses a real file, it skips all of the (slow) standard metadata extraction
    # and derivative generation, instead just SETTING the metadata and derivatives to fixed
    # values (which may not be actually right, but that doesn't matter for many tests).
    #
    # This is much faster, and does work with unsaved Assets and FactoryBot 'build' strategy.
    # But gives you a file that might not have accurate metadata or correct derivatives.
    #
    # In fact, we set all the derivatives to just be the same as the original file.
    #
    # Only is set up to provide metadata and derivatives expected for image/ content-types.
    factory :asset_with_faked_file do
      transient do
        faked_file { File.open((Rails.root + "spec/test_support/images/30x30.png")) }
        faked_content_type { "image/jpeg" }
        faked_width { 30 }
        faked_height { 30 }
        faked_bitrate { nil }
        faked_audio_bitrate { nil }
        faked_video_bitrate { nil }
        faked_filename { nil }
        faked_size { nil }
        faked_duration_seconds  { nil }
        faked_audio_sample_rate { nil }
        faked_md5 { Digest::MD5.hexdigest rand(10000000).to_s }
        faked_sha512 { Digest::SHA512.hexdigest rand(10000000).to_s }
        faked_page_count { nil }

        # other arbitrary metadata
        faked_metadata { {} }

        # An array of Kithe::Derivative objects that we will add to the faked Asset.
        # By default, we take every derivative defined in Kithe::Asset, if they
        # apply to this Asset, and just fake the original asset as the derivative.
        #
        # You can pass in an empty Hash to have no derivatives, or shrine
        # derivatives Hash for specific ones, eg:
        #
        #   { one: create(:stored_uploaded_file, content_type: "image/jpeg") }
        #
        # Nil means we'll create some by default in after(:build)
        faked_derivatives { nil }
      end

      trait :restricted_derivatives do
        published { false }
        derivative_storage_type { "restricted" }
        faked_derivatives {
          {
            "thumb_small" => create(:stored_uploaded_file,
              file: File.open(Rails.root + "spec/test_support/images/20x20.png"),
              storage: "restricted_kithe_derivatives",
              content_type: "image/png"),
            "thumb_large" => create(:stored_uploaded_file,
              file: File.open(Rails.root + "spec/test_support/images/20x20.png"),
              storage: "restricted_kithe_derivatives",
              content_type: "image/png"),
          }
        }
      end

      trait :pdf do
        faked_file { File.open((Rails.root + "spec/test_support/pdf/sample.pdf")) }
        faked_content_type { "application/pdf" }
        faked_height { nil }
        faked_width { nil }
      end

      trait :video do
        title { 'Test video' }
        faked_file { File.open((Rails.root + "spec/test_support/video/sample_video.mp4")) }
        faked_content_type { "video/mpeg" }
        faked_height { nil }
        faked_width { nil }

        transient do
          faked_thumbnail {
            create(:stored_uploaded_file,
              file: File.open((Rails.root + "spec/test_support/images/30x30.png").to_s),
              content_type: "image/jpg",
              width: 760,
              height: 420,
              md5: faked_md5,
              sha512: faked_sha512)
          }
        end

        faked_derivatives {
          {
            thumb_standard: faked_thumbnail,
            thumb_standard_2X: faked_thumbnail,
            thumb_mini: faked_thumbnail,
            thumb_mini_2X: faked_thumbnail,
            thumb_large: faked_thumbnail,
            thumb_large_2x: faked_thumbnail,
          }
        }
      end

      trait :asr_vtt do
        after(:build) do |asset|
          asset.file_attacher.merge_derivatives({
            Asset::ASR_WEBVTT_DERIVATIVE_KEY => build(:stored_uploaded_file, file: StringIO.new("WEBVTT\n\n00:00.000 --> 00:01.500\nASR WebVTT #{rand 100}"), filename: "vtt.vtt", content_type: "text/vtt")
          })
        end
      end

      trait :corrected_vtt do
        after(:build) do |asset|
          asset.file_attacher.merge_derivatives({
            Asset::ASR_WEBVTT_DERIVATIVE_KEY => build(:stored_uploaded_file, file: StringIO.new("WEBVTT\n\n00:00.000 --> 00:01.500\nASR Webvtt #{rand 100}"), filename: "vtt.vtt", content_type: "text/vtt"),
            Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY => build(:stored_uploaded_file, file: StringIO.new("WEBVTT\n\n00:00.000 --> 00:01.500\ncorrected WebVTT #{rand 100}"), filename: "vtt.vtt", content_type: "text/vtt")
          })
        end
      end

      trait :mp3 do
        faked_file { File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3")) }
        faked_content_type { "audio/mpeg" }
        faked_duration_seconds { 5.02 }
        faked_bitrate { 8002 }
        faked_audio_bitrate { 8000 }
        faked_audio_sample_rate { 44100 }
        faked_height { nil }
        faked_width { nil }
        faked_derivatives { nil }
      end

      trait :m4a do
        faked_file { File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.m4a")) }
        faked_content_type { "audio/mp4" }
        faked_duration_seconds { 5.02 }
        faked_bitrate { 8002 }
        faked_audio_bitrate { 8000 }
        faked_audio_sample_rate { 44100 }
        faked_height { nil }
        faked_width { nil }
      end


      trait :flac do
        faked_file { File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.flac")) }
        faked_content_type { "audio/flac" }
        faked_duration_seconds { 5.02 }
        faked_bitrate { 8002 }
        faked_audio_bitrate { 8000 }
        faked_audio_sample_rate { 44100 }
        faked_height { nil }
        faked_width { nil }
      end

      trait :tiff do
        faked_file { File.open((Rails.root + "spec/test_support/images/mini_page_scan.tiff")) }
        faked_content_type { "image/tiff" }
        faked_height { 463 }
        faked_width { 300 }

        # should have full suite of thumbnails, but for now just what we need for PDF tests.
        faked_derivatives do
          {
            graphiconly_pdf: create(:stored_uploaded_file,
                                    file: File.open(Rails.root + "spec/test_support/pdf/mini_page_scan_graphic_only.pdf"))
          }
        end
      end

      after(:build) do |asset, evaluator|
        # Set our uploaded file

        uploaded_file = create(:stored_uploaded_file,
          file: evaluator.faked_file,
          content_type: evaluator.faked_content_type,
          width: evaluator.faked_width,
          height: evaluator.faked_height,
          bitrate:           evaluator.faked_bitrate,
          audio_bitrate:     evaluator.faked_audio_bitrate,
          video_bitrate:     evaluator.faked_bitrate,
          duration_seconds:  evaluator.faked_duration_seconds,
          audio_sample_rate: evaluator.faked_audio_sample_rate,
          md5: evaluator.faked_md5,
          sha512: evaluator.faked_sha512,
          filename: evaluator.faked_filename,
          size: evaluator.faked_size,
          other_metadata: evaluator.faked_metadata,
          page_count: evaluator.faked_page_count)

        asset.file_data = uploaded_file.as_json

        # Now add derivatives for any that work for our faked file type
        if evaluator.faked_derivatives.nil?
          faked = {}
          asset.file_attacher.kithe_derivative_definitions.each do |derivative_defn|
            if derivative_defn.applies_to_content_type?(asset.content_type)
              # We're gonna lie and say the original is a derivative, it won't
              # be the right size, oh well. It also assumes all derivatives
              # result in an image of the same type which isn't true, it
              # won't even be the right type! for many tests, it's okay.
              # When it's not, caller of this factory should supply their own
              # derivatives.

              faked[derivative_defn.key.to_sym] = uploaded_file
            end
          end
          asset.file_attacher.merge_derivatives(faked)
        else
          asset.file_attacher.merge_derivatives(evaluator.faked_derivatives.transform_keys(&:to_sym))
        end
      end
    end

    factory :asset_image_with_correct_sha512, parent: :asset_with_faked_file do
      faked_sha512 { Digest::SHA512.file(Rails.root + "spec/test_support/images/30x30.png").to_s }
    end

    factory :asset_mp3_with_correct_sha512, parent: :asset_with_faked_file do
      faked_file { File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3")) }
      faked_content_type { "audio/mpeg" }
      faked_sha512 { Digest::SHA512.file(Rails.root + "spec/test_support/audio/5-seconds-of-silence.mp3").to_s }
      faked_height { nil }
      faked_width { nil }
    end

    factory :asset_with_faked_source_pdf, parent: :asset_with_faked_file do
      pdf
      role { PdfToPageImages::SOURCE_PDF_ROLE }
      faked_derivatives { { AssetUploader::SCALED_PDF_DERIV_KEY => create(:stored_uploaded_file, content_type: "application/pdf") } }
      faked_page_count  { 10 }
    end
  end
end
