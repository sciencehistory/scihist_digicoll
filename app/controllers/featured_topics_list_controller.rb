# Just the list of all featured topics, see also FeaturedTopicController
class FeaturedTopicsListController < ApplicationController
  def index
    @featured_topics = FeaturedTopic.all
  end
end
