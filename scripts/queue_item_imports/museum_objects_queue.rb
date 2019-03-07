# Google Docs Spreadsheet for Digitization Queue.
#
# Just a temporary hacky thing at present
require 'csv'

CSV.foreach(ARGV[0], headers:true) do |row|
  next unless row["Object Name/Description"].present?

  status = ((row["Open/Closed"] == "closed") ? "closed" : row["Status"])
  # blank status have to look into it
  status = status ? status.downcase.gsub(/[ -]+/, "_") : 'hold'

  Admin::DigitizationQueueItem.create!(
    collecting_area: "museum_objects",
    accession_number: row["no"],
    dimensions: row['Dimensions'],
    materials: row['Materials'],
    instructions: [
      row['# of Components'],
      row['Staging Notes/Handling Issues']
    ].collect(&:presence).compact.join("\n\n"),
    title: row["Object Name/Description"],
    status: status,
    additional_notes: [
      row["Additional Notes"],
      row["Post Production Notes"],
    ].collect(&:presence).compact.join("\n\n")
  )
end
