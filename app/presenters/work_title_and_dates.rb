# Shows the title and dates of a work in the public work display.
#
class WorkTitleAndDates < ViewModel
  valid_model_type_names "Work"


  delegate :genre, :title, :additional_title, :parent, :source, :date_of_work, :published?

  def display
    render "/works/title_and_dates", model: model, view: self
  end

  def display_genres
    GenreLinkListDisplay.new(model.genre).display
  end
end
