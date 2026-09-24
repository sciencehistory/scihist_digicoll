require "open3"
require "down/http"

namespace :scihist do
  namespace :dev do
    namespace :ocr_oh_pdf do
      desc """
        Run the full workflow for OCR'ing a non-text Oral History PDF, and attaching
        it as  ocr_text_only_pdf derivative.

        Download from [staging|production]; run OCR; upload output to S3; attach
        from S3 as derivative in original record on [staging|production]

        ENV['DEPLOYED_TIER'] 'staging' or `production` required, auth required
        for staging.

          DEPLOYED_TIER=staging BASIC_AUTH=shared_name:shared_password ./bin/rake 'scihist:dev:ocr_oh_pdf:process[<friendlier_id1> <friendlier_id2>]'
      """
      task :process, [:friendlier_ids] => :environment do |t, args|
        friendlier_ids = args[:friendlier_ids].to_s.split(/\s+/)
        fail("Usage: rake 'scihist:dev:ocr_oh_pdf:process[friendlier_id1 friendlier_id2 ...]'") if friendlier_ids.empty?

        target_env = ENV["DEPLOYED_TIER"]
        unless %w[staging production].include?(target_env)
          fail("ENV['DEPLOYED_TIER'] must be 'staging' or 'production', got: #{target_env.inspect}")
        end
        unless system("which", "heroku", out: File::NULL, err: File::NULL)
          fail("heroku CLI not found -- needed to run attach remotely. Try `brew install heroku`")
        end

        download_task     = Rake::Task["scihist:dev:ocr_oh_pdf:download"]
        perform_ocr_task  = Rake::Task["scihist:dev:ocr_oh_pdf:perform_ocr"]
        upload_task       = Rake::Task["scihist:dev:ocr_oh_pdf:upload"]

        pairs = friendlier_ids.map do |friendlier_id|
          puts
          puts "Downloading #{friendlier_id}"
          download_task.reenable
          download_task.invoke(friendlier_id)
          original_path = File.join("tmp", "oh_ocr_text_only", "#{friendlier_id}.pdf")

          puts "OCR'ing #{friendlier_id}"
          perform_ocr_task.reenable
          perform_ocr_task.invoke(original_path)
          ocr_path = original_path.sub(/\.pdf\z/i, "") + "-OCR-TEXT-ONLY.pdf"

          puts "Uploading to S3 #{friendlier_id}"
          upload_task.reenable
          upload_task.invoke(ocr_path)

          "#{friendlier_id}:oh_ocr_text_only/#{File.basename(ocr_path)}"
        end

        app_name = "scihist-digicoll-#{target_env}"

        puts "\nAttaching from S3 #{friendlier_ids.join(", ")}"
        remote_command = "rake 'scihist:dev:ocr_oh_pdf:attach_and_process_many[#{pairs.join(" ")},true]'"
         ## --exit-code needed to make sure it passes on exit code of remote process locally, so we can fail.
        unless system("heroku", "run", "--exit-code", remote_command, "--app", app_name)
          fail("heroku run rake scihist:dev:ocr_oh_pdf:attach_and_process_many failed for #{friendlier_ids.join(", ")} (app: #{app_name})")
        end

        puts "\n\nDone -- attached to assets #{friendlier_ids.join(", ")} on #{app_name}"
      end

      desc """
        Download one or more OH PDF Asset originals straight from the public app,

        DEPLOYED_TIER 'staging' or 'production' required, where to download from.

        Will be written to to ./tmp/oh_ocr_text_only/<friendlier_id>.pdf

          BASIC_AUTH=shared_name:shared_password DEPLOYED_TIER=staging ./bin/rake 'scihist:dev:ocr_oh_pdf:download[abc123 def456]'
      """
      task :download, [:friendlier_ids] do |t, args|
        target_env = ENV["DEPLOYED_TIER"]
        unless %w[staging production].include?(target_env)
          fail("ENV['DEPLOYED_TIER'] must be 'staging' or 'production', got: #{target_env.inspect}")
        end

        friendlier_ids = args[:friendlier_ids].to_s.split(/\s+/)
        if friendlier_ids.empty?
          fail("Usage: DEPLOYED_TIER=staging|production rake 'scihist:dev:ocr_oh_pdf:download[friendlier_id1 friendlier_id2 ...]'")
        end

        if target_env == "staging" && ENV["BASIC_AUTH"].blank?
          fail("ENV['BASIC_AUTH'] (formatted as name:password) is required when DEPLOYED_TIER=staging")
        end

        host = target_env == "production" ? "digital.sciencehistory.org" : "staging-digital.sciencehistory.org"

        output_dir = File.join("tmp", "oh_ocr_text_only")
        FileUtils.mkdir_p(output_dir)

        friendlier_ids.each do |friendlier_id|
          url = "https://#{host}/downloads/orig/pdf/#{friendlier_id}"

          begin
            tempfile = Down::Http.download(url) do |client|
              if ENV["BASIC_AUTH"].present?
                user, pass = ENV["BASIC_AUTH"].split(":", 2)
                client.basic_auth(user: user, pass: pass)
              else
                client
              end
            end
          rescue Down::Error => e
            fail("Download failed for #{friendlier_id} (#{url}): #{e.message}")
          end

          output_path = File.join(output_dir, "#{friendlier_id}.pdf")
          FileUtils.mv(tempfile.path, output_path)

          puts "Wrote #{output_path}"
        end
      end

      desc """
        OCR an oral history PDF with ocrmypdf/tesseract, then strip images via
        ghostscript to leave a text-only PDF with the invisible OCR text layer.
        Output is written alongside the input, named <input>-OCR-TEXT-ONLY.pdf.

        Meant to be run in dev, we don't have 'ocrmypdf' CLI dependendency
        available in deployed environments.

          ./bin/rake scihist:dev:ocr_oh_pdf:perform_ocr[./path/to/input.pdf]

        Or pass second arg true to skip the ghostscript image-stripping step and
        keep the OCR'd images instead; output is named <input>-WITH-OCR.pdf.

          ./bin/rake scihist:dev:ocr_oh_pdf:perform_ocr[./path/to/input.pdf,true]
      """
      task :perform_ocr, [:pdf_path, :leave_images] do |t, args|
        pdf_path = args[:pdf_path]
        leave_images = args[:leave_images] == "true"

        fail("Usage: rake scihist:dev:ocr_oh_pdf:perform_ocr[/path/to/input.pdf]") if pdf_path.blank?
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
            ["gs", "-q", "-sDEVICE=pdfwrite", "-dFILTERIMAGE=true", "-o", output_path, "-"]
          )

          unless statuses.all?(&:success?)
            fail("OCR pipeline failed -- ocrmypdf exit #{statuses[0].exitstatus}, gs exit #{statuses[1].exitstatus}")
          end
        end

        puts "Wrote #{output_path}"
      end

      desc """
        Upload a locally-created OCR text-only PDF (see scihist:dev:ocr_oh_pdf:perform_ocr)
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

        puts "Uploaded to `s3://#{bucket_name}/#{s3_key}`"
        puts "  To attach it to an asset, run on the matching Heroku app:"
        puts "    heroku run rake 'scihist:dev:ocr_oh_pdf:attach[#{s3_key.sub(/\Aweb\//, "")},<friendlier_id>]' --app scihist-digicoll-#{target_env}"
      end

      desc """
        Download an OCR text-only PDF previously uploaded via scihist:dev:ocr_oh_pdf:upload to
        Shrine *cache* or 'uploads' bucket, and attach it to the given Asset as :ocr_text_only_pdf
        derivative.

        Meant to be run live on a Heroku-deployed staging or production

          heroku run rake 'scihist:dev:ocr_oh_pdf:attach[oh_ocr_text_only/foo.pdf,<friendlier_id>]' --app scihist-digicoll-staging

        or to clean up source file delete it from storage:

          heroku run rake 'scihist:dev:ocr_oh_pdf:attach[oh_ocr_text_only/foo.pdf,<friendlier_id>,true]' --app scihist-digicoll-staging

        See also scihist:dev:ocr_oh_pdf:extract_pdf_text_paragraphs, to (re-)extract the
        extracted_pdf_text_json derivative from the ocr_text_only_pdf attached here.
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

        puts "Attached `#{s3_key}` to asset `#{friendlier_id}` as derivative `#{AssetUploader::OCR_TEXT_ONLY_PDF}`"
      end

      desc """
        Extract text from an Asset's already-attached `:ocr_text_only_pdf` derivative
        and attach the result as the Asset's `:extracted_pdf_text_json` derivative.

        Also create the OralHistoryContent#paragraph_container if needed.

        The 'source' metadata on the extracted_pdf_text_json derivative will record that it
        came from the ocr_text_only_pdf, and that derivative's id.

        Meant to be run live on a Heroku-deployed staging or production, on an Asset that
        already has an ocr_text_only_pdf derivative attached.

          heroku run rake 'scihist:dev:ocr_oh_pdf:extract_pdf_text_paragraphs[<friendlier_id>]' --app scihist-digicoll-staging
      """
      task :extract_pdf_text_paragraphs, [:friendlier_id] => :environment do |t, args|
        friendlier_id = args[:friendlier_id]
        fail("Usage: rake 'scihist:dev:ocr_oh_pdf:extract_pdf_text_paragraphs[friendlier_id]'") if friendlier_id.blank?

        asset = Asset.find_by_friendlier_id!(friendlier_id)

        ocr_text_only_pdf = asset.file_derivatives[AssetUploader::OCR_TEXT_ONLY_PDF]
        unless ocr_text_only_pdf
          fail("Asset `#{friendlier_id}` has no `#{AssetUploader::OCR_TEXT_ONLY_PDF}` derivative -- run scihist:dev:ocr_oh_pdf:attach first")
        end

        ocr_text_only_pdf.download do |local_file|
          extracted_pdf_text = OralHistory::ExtractPdfText.new(pdf_file_path: local_file.path, source_text_is_ocr: true).extract_pdf_text

          asset.file_attacher.add_persisted_derivatives(
            { extracted_pdf_text_json: StringIO.new(JSON.dump(extracted_pdf_text)) },
            add_metadata: {
              extracted_pdf_text_json: {
                "original_filename" => "extracted_pdf_text.json",
                "mime_type" => "application/json",
                "source" => {
                  "pdf_md5" => Digest::MD5.file(local_file.path).hexdigest,
                  "source_version" => ENV['SOURCE_VERSION'],
                  "created_from_ocr_text_only_pdf" => true,
                  "ocr_text_only_pdf_id" => ocr_text_only_pdf.id
                }
              }
            }
          )
        end

        puts "Attached `extracted_pdf_text_json` (extracted from ocr_text_only_pdf) to asset `#{friendlier_id}`"

        oral_history_content = asset.parent&.oral_history_content
        if oral_history_content && OralHistoryContent::ParagraphContainer.stale?(oral_history_content: oral_history_content)
          OralHistoryContent::ParagraphContainer.create(oral_history_content: oral_history_content, allow_failure_to_sync: true)
          puts "Refreshed `extracted_paragraph_container` for `#{friendlier_id}` -- note oral_history_chunks are now stale and need to be recreated (see OhTranscriptChunkerJob / scihist:validate_oral_history_chunks)"
        end
      end

      desc """
        Attach multiple previously-uploaded OCR text-only PDFs in a single invocation, to avoid
        repeated slow heroku remote execs. For each pair, calls scihist:dev:ocr_oh_pdf:attach to
        attach the ocr_text_only_pdf derivative, then scihist:dev:ocr_oh_pdf:extract_pdf_text_paragraphs
        to (re-)extract extracted_pdf_text_json from it.

        Args are space-separated `friendlier_id:s3_key` pairs.

        Meant to be run live on a Heroku-deployed staging or production

          heroku run \"rake 'scihist:dev:ocr_oh_pdf:attach_and_process_many[<id1>:oh_ocr_text_only/foo.pdf <id2>:oh_ocr_text_only/bar.pdf]'\" --app scihist-digicoll-staging

        or to clean up source files, delete them from storage after attaching:

          heroku run \"rake 'scihist:dev:ocr_oh_pdf:attach_and_process_many[<id1>:oh_ocr_text_only/foo.pdf <id2>:oh_ocr_text_only/bar.pdf,true]'\" --app scihist-digicoll-staging
      """
      task :attach_and_process_many, [:pairs, :delete_from_storage] => :environment do |t, args|
        pairs = args[:pairs].to_s.split(/\s+/)
        fail("Usage: rake 'scihist:dev:ocr_oh_pdf:attach_and_process_many[friendlier_id1:s3_key1 friendlier_id2:s3_key2 ...]'") if pairs.empty?

        attach_task  = Rake::Task["scihist:dev:ocr_oh_pdf:attach"]
        extract_task = Rake::Task["scihist:dev:ocr_oh_pdf:extract_pdf_text_paragraphs"]

        pairs.each do |pair|
          friendlier_id, s3_key = pair.split(":", 2)
          fail("Malformed pair #{pair.inspect}, expected friendlier_id:s3_key") if friendlier_id.blank? || s3_key.blank?

          attach_task.reenable
          attach_task.invoke(s3_key, friendlier_id, args[:delete_from_storage])

          extract_task.reenable
          extract_task.invoke(friendlier_id)
        end
      end
    end
  end
end
