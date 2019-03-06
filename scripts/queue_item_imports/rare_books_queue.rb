# hacky thing to import a CSV representing "Photographs" tab of the legacy
# Google Docs Spreadsheet for Digitization Queue.
#
# Just a temporary hacky thing at present
require 'csv'

CSV.foreach(ARGV[0], headers:true) do |row|
  status = ((row["Open/Closed"] == "closed") ? "closed" : row["Status"])
  # blank status have to look into it
  status = status ? status.downcase.gsub(/[ -]+/, "_") : 'hold'

  Admin::DigitizationQueueItem.create!(
    collecting_area: "rare_books",
    bib_number: row["Bib Number"],
    location: row["Location/Call Number"],
    title: row["Title"],
    scope: row["Scope (Pages, etc.)"],
    status: status,
    additional_notes: [
      row["Additional Notes"],
      row["JM notes"] ? "JM: #{row["JM notes"]}" : nil,
      row["NJ notes"] ? "NJ: #{row["NJ notes"]}" : nil,
    ].collect(&:presence).compact.join("\n\n")
  )
end
