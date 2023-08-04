These are images for use for the home page.
* The component that rotates these and displays them is at app/components/home_page_hero_image_component.rb
* The metadata for these images is  at config/data/home_page_hero_images.yml

### Recipe for creating a new homepage image:

# Start with a large image (at least 2000px wide, ideally significantly more)
# named $original_giant_file.


# pick one of these:
```
new_size = 1000 # for 1x
new_size = 2000 # for 2x
```

```
width=$(vipsheader  -f width  $original_giant_file)
height=$(vipsheader -f height $original_giant_file)
size=$((width > height ? width : height))
factor=$(bc <<< "scale=10; $new_size / $size") # (or 1000)
vips resize $original_giant_file $new_file_name $factor
```