require_relative "env_spec_helper"


describe "System Environment" do
  let(:test_support_dir) { File.absolute_path(File.join(__dir__, "../spec/test_support/")) }
  let(:tmp_output_dir) { File.absolute_path(File.join(__dir__, "../tmp")) }

  describe "mediainfo" do
    it "is present" do
      `mediainfo -h`
    end

    it "has acceptable version" do
      `mediainfo --version` =~ /MediaInfoLib - v(\d+\.\d+)/
      expect($1).to match_version_requirements(">= 2.19")
    end
  end

  describe "imagemagick" do
    let(:version_requirements) { [">= 6.9.10", "< 8"] }

    describe "convert" do
      it "is present" do
        `convert -h`
      end

      it "has acceptable version" do
        `convert -version` =~ /Version: ImageMagick (\d+\.\d+\.\d+)/
        expect($1).to match_version_requirements(*version_requirements)
      end
    end

    describe "identify" do
      it "is present" do
        `identify -help`
      end

      it "has acceptable version" do
        `identify -version` =~ /Version: ImageMagick (\d+\.\d+\.\d+)/
        expect($1).to match_version_requirements(*version_requirements)
      end

      it "runs" do
        input = File.join(test_support_dir, "images/30x30.jpg")
        output = `identify #{input}`
        expect(output).to include "30x30.jpg JPEG 30x30 30x30+0+0 8-bit sRGB"
      end
    end
  end

  describe "pdfunite" do
    it "is present" do
      `pdfunite -h 2>&1`
    end

    it "has acceptable version" do
      `pdfunite -v 2>&1` =~ /pdfunite version (\d+\.\d+.\d+)/
      expect($1).to match_version_requirements(">= 22.02", "< 24")
    end
  end

  describe "vips" do
    let(:version_requirements) { [">= 8.12.1", "< 8.15.0"] }

    it "is present" do
      `vips -h`
    end

    it "has acceptable version" do
      `vips --version` =~ /vips-(\d+\.\d+\.\d+)/
      expect($1).to match_version_requirements(*version_requirements)
    end

    describe "includes build feature" do
      let(:output) { `vips -l` }

      it "pdf load" do
        expect(output).to include "VipsForeignLoadPdf"
      end

      it "jpeg2000 save" do
        expect(output).to include "VipsForeignSaveJp2k"
      end

      it "tiff save" do
        expect(output).to include "VipsForeignSaveTiff"
      end

      it "tiff load" do
        expect(output).to include "VipsForeignLoadTiff"
      end

      it "jpeg save" do
        expect(output).to include "VipsForeignSaveJpeg"
      end
    end

    describe "vipsthumbnail" do
      it "is present" do
        `vipsthumbnail -h`
      end

      it "has acceptable version" do
        `vips --version` =~ /vips-(\d+\.\d+\.\d+)/
        expect($1).to match_version_requirements(*version_requirements)
      end

      it "can read a pdf" do
        input_path =  File.join(test_support_dir, "pdf/sample.pdf")
        output_path = File.join(tmp_output_dir, "sample.jpg")

        `vipsthumbnail #{input_path} -o #{output_path}`
      ensure
        FileUtils.rm(output_path) if File.exist?(output_path)
      end

      it "can write a jp2" do
        input_path =  File.join(test_support_dir, "images/mini_page_scan.tiff")
        output_path = File.join(tmp_output_dir, "sample.jp2")

        # `vipsthumbnail #{input_path} -o #{output_path}[Q=40,subsample-mode=off]`
      ensure
        FileUtils.rm(output_path) if File.exist?(output_path)
      end
    end
  end

  describe "ffmpeg" do
    it "is present" do
      `ffmpeg -h 2>&1`
    end

    it "has acceptable version" do
      `ffmpeg -version` =~ /ffmpeg version (\d+\.\d+\.\d+)/
      expect($1).to match_version_requirements(">= 5.1.2", "< 7")
    end
  end

  describe "qpdf" do
    it "is present" do
      `qpdf --help 2>&1`
    end

    it "has acceptable version" do
      `qpdf --version` =~ /qpdf version (\d+\.\d+\.\d+)/
      expect($1).to match_version_requirements(">= 9.1.1", "< 12")
    end
  end

  describe "python CLI utilities" do
    describe "img2pdf" do
      it "is present" do
        `img2pdf -h`
      end

      it "can create a pdf from a jp2" do
        input_path =  File.join(test_support_dir, "images/30x30.jp2")
        output_path = File.join(tmp_output_dir, "sample.pdf")

        `img2pdf #{input_path} > #{output_path}`
      ensure
        FileUtils.rm(output_path) if File.exist?(output_path)
      end
    end
  end
end
