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

  describe "vips" do
    let(:version_requirements) { [">= 8.12.1", "< 9"] }

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

      it "has acceptable deveversion" do
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
      `ffmpeg -version` =~ /ffmpeg version (\d+\.\d+(\.\d)?)/
      expect($1).to match_version_requirements(">= 5.1.2", "< 8")
    end
  end

  describe "ffprobe" do
    it "is present" do
      `ffprobe -h 2>&1`
    end

    it "has acceptable version" do
      `ffprobe -version` =~ /ffprobe version (\d+\.\d+(\.\d)?)/
      expect($1).to match_version_requirements(">= 5.1.2", "< 8")
    end

    # this was a regression, requires ffmpeg to be linked correctly to network routines
    it "can fetch URLs" do
      `ffprobe https://github.com/mathiasbynens/small/raw/master/mp3.mp3 2>&1`
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

  describe "tesseract" do
    it "is present" do
      `tesseract --help`
    end

    it "has acceptable version" do
      `tesseract --version` =~ /tesseract (\d+\.\d+\.\d+)/
      expect($1).to match_version_requirements(">= 4.1.1", "< 6")
    end

    it "has expected language packs" do
      langs = `tesseract --list-langs`.split

      expect(langs).to include("eng")
      expect(langs).to include("deu")
      expect(langs).to include("fra")
      expect(langs).to include("spa")
    end
  end

  describe "exiftool" do
    it "is present" do
      `exiftool -h`
    end

    it "has acceptable version" do
      ver = `exiftool -ver`.chomp
      expect(ver).to match_version_requirements(">= 12.60", "< 14")
    end
  end

  describe "pdftotext (poppler utility)" do
    it "is present with acceptable version" do
      out = `pdftotext -v 2>&1`

      expect(out).to match(/poppler/i)

      expect(out =~ /version (\d+\.\d+\.\d+)/).not_to be nil
      version = $1
      expect(version).to match_version_requirements(">= 22.0")
    end
  end

  # Should be on heroku automatically, but some issues with heroku-24. custom build script
  # may be needed. See https://www.reddit.com/r/Heroku/comments/1fj3cr4/ghostscript_on_heroku24/
  describe "ghostscript" do
    it "is present with acceptable version" do
      out = `gs -v 2>&1`

      expect(out).to match(/GPL Ghostscript (\d+\.\d+\.\d+)/)
      version = $1
      expect(version).to match_version_requirements(">= 9.55.0")
    end
  end
end
