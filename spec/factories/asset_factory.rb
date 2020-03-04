FactoryBot.define do
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

    trait :inline_promoted_mp3_file_1 do
      file { File.open((Rails.root + "spec/test_support/audio/ice_cubes.mp3")) }
      after(:build) do |asset|
        asset.file_attacher.set_promotion_directives(promote: :inline, create_derivatives: :inline)
      end
    end

    trait :inline_promoted_mp3_file_2 do
      file { File.open((Rails.root + "spec/test_support/audio/double_ice_cubes.mp3")) }
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
        faked_content_type { "image/png" }
        faked_width { 30 }
        faked_height { 30 }

        faked_md5 { Digest::MD5.hexdigest rand(10000000).to_s }
        faked_sha512 { Digest::SHA512.hexdigest rand(10000000).to_s }

        # An array of Kithe::Derivative objects that we will add to the faked Asset.
        # By default, we take every derivative defined in Kithe::Asset, if they
        # apply to this Asset, and just fake the original asset as the derivative.
        #
        # You can pass in an empty array to have no derivatives, or an array of
        # Kithe::Derivative instances (probably created with the :faked_derivative
        # factory below, eg build(:faked_derivative)) for specific ones.
        #
        # Nil means we'll create some by default in after(:build)
        faked_derivatives { nil }
      end

      trait :pdf do
        faked_file { File.open((Rails.root + "spec/test_support/pdf/sample.pdf")) }
        faked_content_type { "application/pdf" }
        faked_height { nil }
        faked_width { nil }
      end

      trait :mp3 do
        faked_file { File.open((Rails.root + "spec/test_support/audio/ice_cubes.mp3")) }
        faked_content_type { "audio/mpeg" }
        faked_height { nil }
        faked_width { nil }
      end

      after(:build) do |asset, evaluator|
        # Set our uploaded file

        uploaded_file = create(:stored_uploaded_file,
          content_type: evaluator.faked_content_type,
          width: evaluator.faked_width,
          height: evaluator.faked_height,
          md5: evaluator.faked_md5,
          sha512: evaluator.faked_sha512)

        asset.file_data = uploaded_file.as_json

        # Now add derivatives for any that work for our faked file type
        if evaluator.faked_derivatives.nil?
          asset.class.derivative_definitions.each do |derivative_defn|
            if derivative_defn.applies_to?(asset)
              # We're gonna lie and say the original is a derivative, it won't
              # be the right size, oh well. It also assumes all derivatives
              # result in an image of the same type which isn't true, it
              # won't even be the right type! for many tests, it's okay.
              # When it's not, caller of this factory should supply their own
              # derivatives.

              derivative = build(:faked_derivative, key: derivative_defn.key, uploaded_file: uploaded_file)
              asset.derivatives << derivative
            end
          end
        else
          evaluator.faked_derivatives.each do |derivative|
            asset.derivatives << derivative
          end
        end
      end
    end

    factory :asset_image_with_correct_sha512, parent: :asset_with_faked_file do
      faked_sha512 { Digest::SHA512.file(Rails.root + "spec/test_support/images/30x30.png").to_s }
    end

    factory :asset_mp3_with_correct_sha512, parent: :asset_with_faked_file do
      faked_file { File.open((Rails.root + "spec/test_support/audio/ice_cubes.mp3")) }
      faked_content_type { "audio/mpeg" }
      faked_sha512 { Digest::SHA512.file(Rails.root + "spec/test_support/audio/ice_cubes.mp3").to_s }
      faked_height { nil }
      faked_width { nil }
    end

  end

  # A Kithe::Derivative object with faked metadata/content-type for file attachment.
  # It does have a real file attachment.
  #
  # To change the attached file/metadata/content-type, pass in a
  # full Shrine::UploadedFile to the `uploaded_file` transient attribute -- probably
  # created with our :stored_uploaded_file factory, as below by default, but maybe with additional attributes.
  #
  # Also note that you can pass in a `key`, otherwise it's thumb_mini.
  factory :faked_derivative, class: Kithe::Derivative do
    transient do
      uploaded_file { build(:stored_uploaded_file) }
    end

    key { "thumb_mini" }
    file_data { uploaded_file.to_json }
  end
end
