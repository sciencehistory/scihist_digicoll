require "open3"

namespace :scihist do
  namespace :dev do
    desc """
      OCR an oral history PDF with ocrmypdf/tesseract, then strip images via
      ghostscript to leave a text-only PDF with the invisible OCR text layer.
      Output is written alongside the input, named <input>-OCR-TEXT-ONLY.pdf.

      Meant to be run in dev, we don't have 'ocrmypdf' CLI dependendency
      available in deployed environments.

      bundle exec rake scihist:dev:ocr_oh_pdf[./path/to/input.pdf]
    """
    task :ocr_oh_pdf, [:pdf_path] do |t, args|
      pdf_path = args[:pdf_path]
      abort("Usage: rake scihist:dev:ocr_oh_pdf[/path/to/input.pdf]") if pdf_path.blank?
      abort("No such file: #{pdf_path}") unless File.exist?(pdf_path)
      unless system("which", "ocrmypdf", out: File::NULL, err: File::NULL)
        abort("ocrmypdf not found. This task is intended only for development machines. Try `brew install ocrmypdf`")
      end
      unless system("which", "gs", out: File::NULL, err: File::NULL)
        abort("gs not found. This task is intended only for development machines. Try `brew bundle`")
      end

      output_path = pdf_path.sub(/\.pdf\z/i, "") + "-OCR-TEXT-ONLY.pdf"

      statuses = Open3.pipeline(
        # --skip-text : don't ocr a page that already has embedded text, not needed
        # --optimize 0 : dont' recompress images leave them alone
        # --tesseract-pagemode 6 : tesseract PSM 6 was needed to succeed at getting page numbers at bottom, which we really need!
        ["ocrmypdf", "--skip-text", "--optimize", "0", "--output-type", "pdf", "--tesseract-pagesegmode", "6", "--quiet", pdf_path, "-"],

        # Then we pipe it through gs to make an invisible text-only PDF, without images,
        # that we'll use to store our OCR info, which can also be input to our PDF text extraction stuff.
        ["gs", "-sDEVICE=pdfwrite", "-dFILTERIMAGE=true", "-o", output_path, "-"]
      )

      unless statuses.all?(&:success?)
        abort("OCR pipeline failed -- ocrmypdf exit #{statuses[0].exitstatus}, gs exit #{statuses[1].exitstatus}")
      end

      puts "\n\nWrote #{output_path}"
    end
  end
end
