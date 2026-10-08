require 'csv'

# Work creation/publication counts, as an HTML table and a CSV export by user.
class Admin::WorkCountReportController < AdminController
  CSV_HEADERS = ["Year", "Month", "Account", "Created Work Count", "Published Work Count"].freeze

  def index
    @months = WorkCountReport.new.months_with_counts
  end

  # CSV of WorkCountByUserReport for the months in params[:from_month] to params[:to_month], as yyyy-mm.
  def export_work_count_by_user
    from_month = parse_month(params[:from_month])
    to_month = parse_month(params[:to_month])

    if from_month.nil? || to_month.nil? || from_month > to_month
      redirect_to admin_work_count_report_path, alert: "Enter first and last month as yyyy-mm, with the first not after the last"
      return
    end

    rows = WorkCountByUserReport.new(from_month: from_month, to_month: to_month).rows

    csv = CSV.generate do |out|
      out << CSV_HEADERS
      rows.each do |row|
        out << [row.month.year, Date::MONTHNAMES[row.month.month], row.account, row.created_count, row.published_count]
      end
    end

    send_data csv, type: "text/csv", filename: "work_counts_by_user_#{from_month.strftime("%Y-%m")}_to_#{to_month.strftime("%Y-%m")}.csv"
  end

  private

  # @return [Date, nil] first day of the month, nil if not yyyy-mm
  def parse_month(string)
    Date.strptime(string.to_s.strip, "%Y-%m") if string.to_s.strip.match?(/\A\d{4}-\d{2}\z/)
  rescue Date::Error
    nil
  end
end
