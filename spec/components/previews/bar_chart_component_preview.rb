# Preview in dev at:
#
#  http://localhost:3000/rails/view_components/bar_chart_component/
class BarChartComponentPreview < ViewComponent::Preview

  def default
    render BarChartComponent.new(
      caption: "Items per month",
      groups: {
        "July 2026" => {
          "Created"   => { total: 210, current: 12 },
          "Published" => { total: 220, current: 8 }
        },
        "August 2026" => {
          "Created"   => { total: 240, current: 30 },
          "Published" => { total: 275, current: 55 }
        },
        "Sep 2026" => {
          "Created"   => { total: 252, current: 12 },
          "Published" => { total: 280, current: 5 }
        }
      }
    )
  end
end
