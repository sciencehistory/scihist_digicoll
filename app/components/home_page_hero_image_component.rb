# Show the hero image on the home page.
#
# We keep a certain number of images, along with a bit of metadata for each,
# in a config file at YAML_SOURCE_PATH.
#
# We show each image to all viewers, for a period of ten minutes.
# Then we move on to the next one, and so on.
#
# For testing each image, you can override this mechanism
# by specifying ?hero_image=1, ?hero_image=2, and so on.
class HomePageHeroImageComponent < ApplicationComponent
  YAML_SOURCE_PATH = Rails.root.join("config/data/home_page_hero_images.yml").to_s
  HOW_LONG_TO_SHOW_EACH_IMAGE = 10 * 60 # seconds

  def initialize(override:nil)
    @override = override
  end

  def path
    image_metadata['path']
  end
  
  def path_1x
    image_metadata['path_1x']
  end
  
  def path_2x
    image_metadata['path_2x']
  end



  def link_title
    image_metadata['link_title']
  end

  def work_friendlier_id
    image_metadata['work_friendlier_id']
  end

  private

  def src_attributes
    {
       src: res_1x_url,
       srcset: "#{res_1x_url} 1x, #{res_2x_url} 2x"
    }
  end

  # a large integer that increments when it's time for the image to change.
  def tick
    Time.now.to_i.div(HOW_LONG_TO_SHOW_EACH_IMAGE)
  end

  # returns an index we can use to choose an image from the all_images_metadata array
  def image_number
    number_of_images = all_images_metadata.length
    n = @override.to_i
    # Ignore @override if it's the wrong type or size.
    if n.to_s == @override && n.between?(1, number_of_images)
      n - 1
    else
      tick % number_of_images
    end
  end

  # Choose an image based on the tick
  def image_metadata
    @image_metadata ||= all_images_metadata[image_number]
  end

  def all_images_metadata
    @all_images_metadata ||= YAML.load_file(YAML_SOURCE_PATH)['images']
  end
end