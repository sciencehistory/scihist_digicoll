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
    trait :faked_image_file do
      transient do
        faked_file { File.open((Rails.root + "spec/test_support/images/30x30.png")) }
        faked_content_type { "image/png" }
        faked_width { 30 }
        faked_height { 30 }
      end
      after(:build) do |asset, evaluator|
        # Set our uploaded file

        uploaded_file = create(:stored_uploaded_file)
        asset.file_data = uploaded_file.to_json

        # Now add derivatives for any that work for our faked file type
        asset.class.derivative_definitions.each do |derivative_defn|
          if derivative_defn.applies_to?(asset)
            derivative = Kithe::Derivative.new(key: derivative_defn.key)

            # We're gonna lie and say the original is a derivative, it won't
            # be the right size, oh well. It also assumes all derivatives
            # result in an image of the same type which isn't true, it
            # won't even be the right type! for many tests, it's okay.
            # When it's not, caller of this factory should supply their own
            # derivatives.
            derivative.file_data = uploaded_file.to_json
            asset.derivatives << derivative
          end
        end
      end
    end

    trait :no_derivatives_creation do
      after(:build) do |asset|
        asset.file_attacher.set_promotion_directives(create_derivatives: false)
      end
    end
  end
end
