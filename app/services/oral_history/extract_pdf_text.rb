module OralHistory
  # Extracts text from an OH PDF, expecting certain conventions.
  #
  # 1. Will use our extract_pdf_text.py python helper based on PyMyPDF to
  #    get a json representation that is pretty structural.
  #
  # 2. TBD: Will then use some heuristics to extract standardized trasncript
  #    paragraphs out of it (ignoring prefatory material and post-transcript
  #    material)
  class ExtractPdfText
    class_attribute :extract_pdf_text_command,
      default: ScihistDigicoll::Util.prefix_python_exec_command("./python_script/extract_pdf_text.py")

    attr_reader :pdf_file_path

    def initialize(pdf_file_path:)
      @pdf_file_path = pdf_file_path.to_s
    end

    # use our extract_pdf_text.py python helper based on PyMyPDF to
    # get a json-compat hash representation that is pretty structural.
    def extract_pdf_text
      out, err = TTY::Command.new(printer: :null).run(extract_pdf_text_command, pdf_file_path)

      return JSON.parse(out)
    end

  end
end
