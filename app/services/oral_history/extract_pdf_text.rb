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
    class Error < StandardError ; end

    class_attribute :extract_pdf_text_command,
      default: ScihistDigicoll::Util.prefix_python_exec_command("./python_script/extract_pdf_text.py")

    attr_reader :pdf_file_path

    def initialize(pdf_file_path:)
      @pdf_file_path = pdf_file_path.to_s
    end

    # use our extract_pdf_text.py python helper based on PyMyPDF to
    # get a json-compat hash representation that is pretty structural.
    #
    # Will validate against our JSON schema and raise if invalid!
    def extract_pdf_text(validate: true)
      out, err = extract_pdf_text_tty_command.run(extract_pdf_text_command, pdf_file_path)

      parsed = JSON.parse(out)
      if validate
        validate_extract_pdf_text_json(parsed)
      end

      parsed
    rescue TTY::Command::ExitError, JSON::ParserError => e
      raise Error.new("#{e.class.name}: #{e.message}")
    end

    private

    # mostly to make it easy to mock in tests
    def extract_pdf_text_tty_command
      @extract_pdf_text_tty_command ||= TTY::Command.new(printer: :null)
    end

    def validate_extract_pdf_text_json(as_json)
      errors = JSON_SCHEMER.validate(as_json).to_a

      if errors.present?
        error_msg = errors.collect { |h| h["error"] }.join(", ")
        raise Error.new("response is not valid for expected schema: #{error_msg}}")
      end
    end

    public

    JSON_SCHEMER = JSONSchemer.schema(
      {
        "$schema": "https://json-schema.org/draft/2020-12/schema",
        "type": "object",
        "required": ["pages"],
        "properties": {
          "pages": {
            "type": "array",
            "items": { "$ref": "#/$defs/page" }
          }
        },

        "$defs": {
          "page": {
            "type": "object",
            "required": ["width", "height", "blocks"],
            "properties": {
              "width": { "type": "number" },
              "height": { "type": "number" },
              "blocks": {
                "type": "array",
                "items": { "$ref": "#/$defs/block" }
              }
            }
          },

          "block": {
            "type": "object",
            "description": "Layout block heuristically identified by PyMuPDF",
            "required": ["bbox", "paragraphs"],
            "properties": {
              "bbox": { "$ref": "#/$defs/bbox" },
              "paragraphs": {
                "type": "array",
                "items": { "$ref": "#/$defs/paragraph" }
              }
            }
          },

          "paragraph": {
            "type": "object",
            "description": "Paragraph created heuristically by extract_pdf_text.py from lines identified by PyMyPDF",
            "required": ["bbox", "text"],
            "properties": {
              "bbox": { "$ref": "#/$defs/bbox" },
              "text": { "type": "string" }
            }
          },

          "bbox": {
            "type": "object",
            "description": "Bounding box provided by PyMuPDF, rectangle location on page in PDF 72dpi pixels",
            "required": ["x0", "y0", "x1", "y1"],
            "properties": {
              "x0": { "type": "number" },
              "y0": { "type": "number" },
              "x1": { "type": "number" },
              "y1": { "type": "number" }
            }
          }
        }
      }
    )
  end
end
