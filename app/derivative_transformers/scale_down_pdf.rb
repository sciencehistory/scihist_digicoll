# Takes an original (expected use case: born-digital) PDF, and scales images down
# to 72 dpi by running it through the ghostscript `screen` pseudo-device (screen-optimized
# according to an old Adobe profile)
#
# See relevant ghostscript options and definition of screen pseudo-device and others
# at https://ghostscript.readthedocs.io/en/gs10.0.0/VectorDevices.html#the-family-of-pdf-and-postscript-output-devices
#
class ScaleDownPdf
  class_attribute :ghostscript_command, default: "gs"
  # gs ebook pre-set is 150dpi, and we decided was best compromise for a screen view. 72 dpi
  # "screen" preset looked chunky. 150 "ebook" looks good
  class_attribute :ghostscript_pseudo_device, default: "ebook"
  DPI = 150

  # @param linearize [Boolean] "linearizing" with fast web view increases size somewhat, but makes web loading faster.
  #     matters more the bigger PDFs, caller just tell us if you want it.
  def call(original, linearize: false)
    output_tempfile = Tempfile.new([self.class.name, ".pdf"])

    cmd = TTY::Command.new(printer: :null)

    args = [
      ghostscript_command,
      #
      ("-dFastWebView" if linearize),
      "-sDEVICE=pdfwrite",
      "-dPDFSETTINGS=/#{ghostscript_pseudo_device}",
      "-q",
      "-o", output_tempfile.path,
      original.path
    ].compact

    cmd.run(*args)

    return output_tempfile
  end
end
