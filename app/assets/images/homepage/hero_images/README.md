# Home page hero images
The images in these directories are the large "hero" images used on the home page.
* The component that displays these is at `app/components/home_page_hero_image_component.rb`
* The metadata for these images is at `config/data/home_page_hero_images.yml`
  * Metadata includes links to the original crops on the P drive.
* See also https://github.com/sciencehistory/scihist_digicoll/issues/2140

## Create a new home page hero image:

1) Start with a large TIFF file
  * Cropped as simply as possible from an original TIFF asset
  * Wider than 2000px
  * Aspect ratio: 10 x 7
2) Upload the cropped image to the P drive and save the URL
3) Resize your original image:
```
vipsthumbnail cropped_original.tiff --size 1000x -o homepage/hero_images/1x/new_file_1x.jpg
vipsthumbnail cropped_original.tiff --size 2000x -o homepage/hero_images/1x/new_file_2x.jpg
```
4) Add metadata into `config/data/home_page_hero_images.yml`