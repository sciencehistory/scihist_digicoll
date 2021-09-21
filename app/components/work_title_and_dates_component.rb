# Shows the title and dates of a work in the public work display.
#
class WorkTitleAndDatesComponent < ApplicationComponent
  attr_reader :work

  # delegate to WORK
  delegate :genre, :title, :additional_title, :parent, :source, :date_of_work, :published?, to: :work

  delegate :publication_badge, :can?, to: :helpers

  def initialize(work)
    @work = work
  end



  def display_genres
    render GenreLinkListComponent.new(work.genre)
  end
end
