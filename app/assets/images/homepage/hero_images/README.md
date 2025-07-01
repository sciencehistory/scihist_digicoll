# Home page hero images
The images in these directories are the large "hero" images used on the home page.
* The component that displays these is at `app/components/home_page_hero_image_component.rb`
* The metadata for these images is at `config/data/home_page_hero_images.yml`
  * Metadata includes links to the original crops on the P drive.
* See also https://github.com/sciencehistory/scihist_digicoll/issues/2140

## Create a new home page hero image:
1) Select an asset
Prefer colorful subjects or people doing science, especially people from under-represented communities.
2) Download the image's original TIFF.
  * Crop the downloaded TIFF:
    * Wider than 2000px
    * Aspect ratio: 10 x 7
    * Image composition should fill the display window flatteringly.
  	  * Check different screen sizes
  	  * Avoid cropped heads
2) Upload the cropped image to the P drive and save the URL
3) Resize your original image:
```

ORIGINAL=greene.jpg
DESTINATION=greene.webp

vipsthumbnail $ORIGINAL --size 250x  -o app/assets/images/homepage/hero_images/1x/$DESTINATION
vipsthumbnail $ORIGINAL --size 500x  -o app/assets/images/homepage/hero_images/2x/$DESTINATION
vipsthumbnail $ORIGINAL --size 1000x -o app/assets/images/homepage/hero_images/4x/$DESTINATION
vipsthumbnail $ORIGINAL --size 2000x -o app/assets/images/homepage/hero_images/8x/$DESTINATION
```
4) Add metadata into `config/data/home_page_hero_images.yml`