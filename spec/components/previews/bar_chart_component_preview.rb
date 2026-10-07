# Preview in dev at:
#
#  http://localhost:3000/rails/view_components/bar_chart_component/
class BarChartComponentPreview < ViewComponent::Preview

  def default
    render BarChartComponent.new(
      caption: "Items per month",
      series: ["Created", "Published"],
      groups: {
        "July 2026"   => [210, 220],
        "August 2026" => [240, 275],
        "Sep 2026"    => [252, 280]
      }
    )
  end
end
