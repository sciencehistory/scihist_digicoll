# Home page hero images
The images in these directories are the large "hero" images used on the home page.
* The component that displays these is at `app/components/home_page_hero_image_component.rb`
* The metadata for these images is at `config/data/home_page_hero_images.yml`
* Metadata includes links to the original crops on the P drive.
* See also https://github.com/sciencehistory/scihist_digicoll/issues/2140

### To create a new home page hero image
This creates an image with its largest side equal to 1000px or 2000px.

1) Start with a large image (at least 2000px wide, ideally significantly more) named $original_giant_file.

2) Use one of these sizes:
```
new_size = 1000 # to get the 1x image
new_size = 2000 # to get the 2x image
```
3) Resize your original image:
```
width=$(vipsheader  -f width  $original_giant_file)
height=$(vipsheader -f height $original_giant_file)
size=$((width > height ? width : height))
factor=$(bc <<< "scale=10; $new_size / $size")
vips resize $original_giant_file $new_file_name $factor
```