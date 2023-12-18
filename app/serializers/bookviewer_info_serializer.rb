# Json-compat hash serializer for info for the scihist_viewer
# Returned by an HTTP endpoint for viewer.
#
#     ViewerMemberInfoSerializer.new(work).as_hash
#
#
class BookviewerInfoSerializer
  include Rails.application.routes.url_helpers

  THUMB_DERIVATIVE = :thumb_mini

  attr_reader :work, :show_unpublished

  def initialize(work, show_unpublished: false)
    @work = work
    @show_unpublished = show_unpublished
  end

  def as_hash
    {
       data: {
        lendingInfo: {
           lendingStatus: nil,
           userid: 0,
           isAdmin: false,
           isArchiveOrgLending: false,
           isOpenLibraryLending: false,
           isLendingRequired: false,
           isBrowserBorrowable: false,
           isPrintDisabledOnly: false,
           isAvailable: false,
           isAvailableForBrowsing: false,
           userHasBorrowed: false,
           userHasBrowsed: false,
           userOnWaitingList: false,
           userHoldIsReady: false,
           userIsPrintDisabled: false,
           shouldProtectImages: false,
           daysLeftOnLoan: 0,
           secondsLeftOnLoan: 0,
           loansUrl: "",
           bookUrl: "",
           loanCount: 0,
           totalWaitlistCount: 0,
           userWaitlistPosition: -1,
           maxLoans: 10,
           loanRecord: [],
        },
        metadata: {
          title: work.title,
          volume: "1",
          creator: [ work.creator.to_s ],
          description: work.description,
          date: "1848-1854",
          "language": "eng",
          "copyright-evidence-operator": "james-hixon",
          "possible-copyright-status": "NOT_IN_COPYRIGHT",
          "copyright-region": "US",
          "copyright-evidence": "Evidence reported by james-hixon for item theworksofplato01platiala on June 8, 2007: no visible notice of copyright; stated date is 1848.",
          "copyright-evidence-date": "20070608000518",
          "sponsor": "MSN",
          "contributor": "University of California Libraries",
          "scanningcenter": "iala",
          "mediatype": "texts",
          "call_number": "SRLF:LAGE-2757470",
          "collection-library": "SRLF",
          "identifier-bib": "LAGE-2757470",
          "updatedate": "2007-06-08 00:05:46",
          "updater": "james-hixon",
          "identifier": "theworksofplato01platiala",
          "uploader": "scanner-james-hixon@archive.org",
          "addeddate": "2007-06-08 00:05:48",
          "publicdate": "2007-06-08 00:05:51",
          "imagecount": "528",
          "ppi": "400",
          "lcamid": "1020707125",
          "rcamid": "1420900962",
          "camera": "5D",
          "operator": "scanner-my-hy@archive.org",
          "scanner": "iala9",
          "scandate": "20070608143750",
          "identifier-access": "http://www.archive.org/details/theworksofplato01platiala",
          "identifier-ark": "ark:/13960/t9m32qs2m",
          "bookplateleaf": "0006",
          "curation": "[curator]marcus@archive.org[/curator][date]20070705232255[/date][state]approved[/state]",
          "sponsordate": "20070630",
          "filesxml": [
            "Thu Mar 18 12:05:39 UTC 2010",
            "Sat Dec 26 11:53:08 UTC 2020"
          ],
          "collection": [
            "cdl",
            "americana"
          ],
          "foldoutcount": "0",
          "repub_state": "4",
          "backup_location": "ia903601_1",
          "openlibrary_edition": "OL48596445M",
          "openlibrary_work": "OL36001028W",
          "external-identifier": "urn:oclc:record:874775479",
          "ocr_module_version": "0.0.14",
          "ocr_converted": "abbyy-to-hocr 1.1.11",
          "page_number_confidence": "96.56",
          "associated-names": "Burges, George, 1786?-1864; Cary, Henry, 1804-1870; Davis, Henry"
        },
        "data": {
          "streamOnly": false,
          "isRestricted": false,
          "id": "theworksofplato01platiala",
          "subPrefix": "theworksofplato01platiala",
          "olHost": "https://openlibrary.org",
          "bookUrl": "/details/theworksofplato01platiala",
          "downloadUrls": [
            [
              "PDF",
              "//archive.org/download/theworksofplato01platiala/theworksofplato01platiala.pdf"
            ],
            [
              "ePub",
              "//archive.org/download/theworksofplato01platiala/theworksofplato01platiala.epub"
            ],
            [
              "Plain Text",
              "//archive.org/download/theworksofplato01platiala/theworksofplato01platiala_djvu.txt"
            ],
            [
              "DAISY",
              "//archive.org/download/theworksofplato01platiala/theworksofplato01platiala_daisy.zip"
            ],
            [
              "Kindle",
              "//archive.org/download/theworksofplato01platiala/theworksofplato01platiala.mobi"
            ]
          ]
        },
        brOptions: {
          "bookId": "theworksofplato01platiala",
          "bookPath": "/25/items/theworksofplato01platiala/theworksofplato01platiala",
          "imageFormat": "jp2",
          "server": "ia800900.us.archive.org",
          "subPrefix": "theworksofplato01platiala",
          "zip": "/25/items/theworksofplato01platiala/theworksofplato01platiala_jp2.zip",
          bookTitle: work.title,
          "ppi": "400",
          "titleLeaf": 7,
          "coverLeaf": 1,
          "defaultStartLeaf": 1,
          "pageProgression": "lr",
          "vars": {
            "bookId": "theworksofplato01platiala",
            "bookPath": "/25/items/theworksofplato01platiala/theworksofplato01platiala",
            "server": "ia800900.us.archive.org",
            "subPrefix": "theworksofplato01platiala"
          },
          thumbnail: work.leaf_representative.file_url(THUMB_DERIVATIVE),
          "plugins": {
            "textSelection": {
              "enabled": true,
              "singlePageDjvuXmlUrl": "https://{{server}}/BookReader/BookReaderGetTextWrapper.php?path={{bookPath|urlencode}}_djvu.xml&mode=djvu_xml&page={{pageIndex}}"
            }
          },
          # the actual list of pages is here:
          data: included_members.map  { |a| [{ width: a.width, height: a.height, uri: a.file_url(:thumb_large_2X)}] },
         }
      },
    }
  end

  private

  def included_members
    @included_members ||= begin
      members = work.members.order(:position)
      members = members.where(published: true) unless show_unpublished
      members.includes(:leaf_representative).select do |member|
        member.leaf_representative &&
        member.leaf_representative.content_type&.start_with?("image/") &&
        member.leaf_representative.stored?
      end
    end
  end

  # def download_options(asset)
  #   # include the PDF link here if we only have one image, as there won't be a
  #   # fixed whole-work download section, but we still want it.
  #   DownloadOptions::ImageDownloadOptions.new(asset, show_pdf_link: work.member_count == 1).options
  # end

  def thumb_src_attributes(asset)
    derivative_1x_url = asset.file_url(THUMB_DERIVATIVE)
    #derivative_2x_url = asset.file_url("#{THUMB_DERIVATIVE.to_s}_2X")
    {
      thumbSrc: derivative_1x_url,
      #thumbSrcset: "#{derivative_1x_url} 1x, #{derivative_2x_url} 2x"
    }
  end


end
