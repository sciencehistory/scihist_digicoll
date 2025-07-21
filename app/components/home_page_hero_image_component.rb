# Show the hero image on the home page.
#
# We keep a certain number of images, along with a bit of metadata for each,
# in a config file at YAML_SOURCE_PATH.
#
# We show each image to all viewers, for a period of ten minutes.
# Then we move on to the next one, and so on.
# The number of images is arbitrary.
#
# For testing each image, you can override this mechanism
# by specifying ?hero_image=1, ?hero_image=2, and so on.
#
# Paths to the original files (on the P drive) are stored in the YML file.
#
# We parse and validate the YAML file on class load and store it in a class variable.
# Otherwise it would be fairly easy to break the home page -- in a delayed fashion --
# on account of a careless error in the configuration file.
# 
# For notes on how to create a new hero image, see:
# See images/homepage/hero_images/README.md
class HomePageHeroImageComponent < ApplicationComponent
  YAML_SOURCE_PATH = Rails.root.join("config/data/home_page_hero_images.yml").to_s
  HOW_LONG_TO_SHOW_EACH_IMAGE = 10 * 60 # seconds

  def initialize(override:nil)
    @override = override
  end

  def path_250
    image_metadata['path_250']
  end
  
  def path_500
    image_metadata['path_500']
  end

  def path_1000
    image_metadata['path_1000']
  end

  def path_2000
    image_metadata['path_2000']
  end

  def link_title
    image_metadata['link_title']
  end

  def work_friendlier_id
    image_metadata['work_friendlier_id']
  end

  private

  # returns an integer that increments when the image needs to change
  def tick
    Time.now.to_i.div(HOW_LONG_TO_SHOW_EACH_IMAGE)
  end

  # returns the metadata for an image to show.
  # Ignores @override if it's nil, not a number, or the wrong size.
  def image_metadata
    @image_metadata ||= begin
      n = @override.to_i
      if (n.to_s == @override && n.between?(1, number_of_images))
        self.class.all_images_metadata[ n - 1 ]
      else        
        self.class.all_images_metadata[ tick % number_of_images ]
      end
    end
  end

  def number_of_images
    @number_of_images ||= self.class.all_images_metadata.length
  end

  def self.all_images_metadata
    @@all_images_metadata ||= YAML.load_file(YAML_SOURCE_PATH)['images']
  end
end