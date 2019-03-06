# hacky thing to import a CSV representing "Photographs" tab of the legacy
# Google Docs Spreadsheet for Digitization Queue.
#
# Just a temporary hacky thing at present
require 'csv'

CSV.foreach(ARGV[0], headers:true) do |row|
  status = ((row["Open/Closed"] == "closed") ? "closed" : row["Status"])
  status = status.downcase.gsub(/[ -]+/, "_")

  Admin::DigitizationQueueItem.create!(
    collecting_area: "photographs",
    title: row["Title"],
    accession_number: row["Accession Number"],
    scope: row["Scope (Pages, etc.)"],
    bib_number: row["Bib Number"],
    location: row["Home Location"],
    status: status,
    box: row["Box/Folder/Object ID Number"],
    copyright_status: row["Copyright Status/Holder"],
    additional_notes: [
      row["New Collection Record Needed? / Additional Notes"],
      row["Notes"]
    ].collect(&:presence).compact.join("\n\n")
  )
end
