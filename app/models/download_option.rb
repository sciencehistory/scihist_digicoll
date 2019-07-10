# A simple value object representing a download option, used for constructing our download
# menus
class DownloadOption
  attr_reader :label, :subhead, :url, :analyticsAction

  def initialize(label, subhead:, url:, analyticsAction:nil)
    @label = label
    @subhead = subhead
    @url = url
    @analyticsAction = analyticsAction
  end

end
