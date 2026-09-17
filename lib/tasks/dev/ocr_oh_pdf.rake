require "open3"

namespace :scihist do
  namespace :dev do
    namespace :ocr_oh_pdf do
      desc """
        OCR an oral history PDF with ocrmypdf/tesseract, then strip images via
        ghostscript to leave a text-only PDF with the invisible OCR text layer.
        Output is written alongside the input, named <input>-OCR-TEXT-ONLY.pdf.

        Meant to be run in dev, we don't have 'ocrmypdf' CLI dependendency
        available in deployed environments.

          bundle exec rake scihist:dev:ocr_oh_pdf:create[./path/to/input.pdf]

        Or pass second arg true to skip the ghostscript image-stripping step and
        keep the OCR'd images instead; output is named <input>-WITH-OCR.pdf.

          bundle exec rake scihist:dev:ocr_oh_pdf:create[./path/to/input.pdf,true]
      """
      task :create, [:pdf_path, :leave_images] do |t, args|
        pdf_path = args[:pdf_path]
        leave_images = args[:leave_images] == "true"

        fail("Usage: rake scihist:dev:ocr_oh_pdf:create[/path/to/input.pdf]") if pdf_path.blank?
        fail("No such file: #{pdf_path}") unless File.exist?(pdf_path)
        unless system("which", "ocrmypdf", out: File::NULL, err: File::NULL)
          fail("ocrmypdf not found. This task is intended only for development machines. Try `brew install ocrmypdf`")
        end

        # --skip-text : don't ocr a page that already has embedded text, not needed
        # --optimize 0 : dont' recompress images leave them alone
        # --tesseract-pagemode 6 : tesseract PSM 6 was needed to succeed at getting page numbers at bottom, which we really need!
        ocrmypdf_args = ["--skip-text", "--optimize", "0", "--output-type", "pdf", "--tesseract-pagesegmode", "6", "--quiet"]

        if leave_images
          output_path = pdf_path.sub(/\.pdf\z/i, "") + "-WITH-OCR.pdf"

          unless system("ocrmypdf", *ocrmypdf_args, pdf_path, output_path)
            fail("OCR failed -- ocrmypdf exit #{$?.exitstatus}")
          end
        else
          unless system("which", "gs", out: File::NULL, err: File::NULL)
            fail("gs not found. This task is intended only for development machines. Try `brew bundle`")
          end

          output_path = pdf_path.sub(/\.pdf\z/i, "") + "-OCR-TEXT-ONLY.pdf"

          statuses = Open3.pipeline(
            ["ocrmypdf", *ocrmypdf_args, pdf_path, "-"],

            # Pipe ocrmypdf's output through gs to make an invisible text-only PDF, without
            # images, that we'll use to store our OCR info, which can also be input to our
            # PDF text extraction stuff.
            ["gs", "-sDEVICE=pdfwrite", "-dFILTERIMAGE=true", "-o", output_path, "-"]
          )

          unless statuses.all?(&:success?)
            fail("OCR pipeline failed -- ocrmypdf exit #{statuses[0].exitstatus}, gs exit #{statuses[1].exitstatus}")
          end
        end

        puts "\n\nWrote #{output_path}"
      end

      desc """
        Upload a locally-created OCR text-only PDF (see scihist:dev:ocr_oh_pdf:create)
        to the S3 'uploads' (shrine `cache`) bucket for staging or production, under oh_ocr_text_only/,
        so it can later be picked up by scihist:dev:ocr_oh_pdf:attach running on that tier.

        Meant to be run in dev. Requires ENV['DEPLOYED_TIER'] to be 'staging' or 'production'.

        DEPLOYED_TIER=staging ./bin/rake scihist:dev:ocr_oh_pdf:upload[./path/to/input-OCR-TEXT-ONLY.pdf]
      """
      task :upload, [:pdf_path] => :environment do |t, args|
        pdf_path = args[:pdf_path]
        target_env = ENV["DEPLOYED_TIER"]

        fail("Usage: DEPLOYED_TIER=staging|production rake scihist:dev:ocr_oh_pdf:upload[/path/to/input.pdf]") if pdf_path.blank?
        fail("No such file: #{pdf_path}") unless File.exist?(pdf_path)
        unless %w[staging production].include?(target_env)
          fail("ENV['DEPLOYED_TIER'] must be 'staging' or 'production', got: #{target_env.inspect}")
        end

        bucket_name = "scihist-digicoll-#{target_env.downcase}-uploads"

        s3_key = "web/oh_ocr_text_only/#{File.basename(pdf_path)}"

        aws_client = Aws::S3::Client.new(
          access_key_id:     ScihistDigicoll::Env.lookup!(:aws_access_key_id),
          secret_access_key: ScihistDigicoll::Env.lookup!(:aws_secret_access_key),
          region:            ScihistDigicoll::Env.lookup!(:aws_region)
        )

        Aws::S3::TransferManager.new(client: aws_client).upload_file(
          pdf_path, bucket: bucket_name, key: s3_key, content_type: "application/pdf"
        )

        puts "\n\nUploaded to `s3://#{bucket_name}/#{s3_key}`"
        puts "\nTo attach it to an asset, run on the matching Heroku app:"
        puts "  heroku run rake 'scihist:dev:ocr_oh_pdf:attach[#{s3_key.sub(/\Aweb\//, "")},<friendlier_id>]' --app scihist-digicoll-#{target_env}"
      end

      desc """
        Download an OCR text-only PDF previously uploaded via scihist:dev:ocr_oh_pdf:upload to
        Shrine *cache* or 'uploads' bucket, and attach it to the given Asset as :ocr_text_only_pdf
        derivative.

        Meant to be run live on a Heroku-deployed staging or production

          heroku run rake 'scihist:dev:ocr_oh_pdf:attach[oh_ocr_text_only/foo.pdf,<friendlier_id>]' --app scihist-digicoll-staging

        or to clean up source file delete it from storage:

          heroku run rake 'scihist:dev:ocr_oh_pdf:attach[oh_ocr_text_only/foo.pdf,<friendlier_id>,true]' --app scihist-digicoll-staging
      """
      task :attach, [:s3_key, :friendlier_id, :delete_from_storage] => :environment do |t, args|
        s3_key = args[:s3_key]
        friendlier_id = args[:friendlier_id]
        delete_from_storage = args[:delete_from_storage] == "true"

        if s3_key.blank? || friendlier_id.blank?
          fail("Usage: rake 'scihist:dev:ocr_oh_pdf:attach[s3_key,friendlier_id]'")
        end
        if Rails.env.development?
          warn("This normally is meant to be run on a deployed staging or production server!")
        end

        asset = Asset.find_by_friendlier_id!(friendlier_id)
        unless asset.content_type == "application/pdf"
          fail("This is only meant to be used with PDF Assets, this one is #{asset.content_type}")
        end

        begin
          io = ScihistDigicoll::Env.shrine_cache_storage.open(s3_key)
        rescue Shrine::FileNotFound
          fail("No such S3 object: #{s3_key.inspect} (in shrine cache storage, #{ScihistDigicoll::Env.shrine_cache_storage.bucket.name})")
        end

        asset.file_attacher.add_persisted_derivatives({ AssetUploader::OCR_TEXT_ONLY_PDF => io })

        ScihistDigicoll::Env.shrine_cache_storage.delete(s3_key) if delete_from_storage

        puts "\n\nAttached `#{s3_key}` to asset `#{friendlier_id}` as derivative `#{AssetUploader::OCR_TEXT_ONLY_PDF}`"
      end
    end
  end
end
