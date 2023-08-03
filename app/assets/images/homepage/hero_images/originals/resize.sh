max_size=2000
width=$(vipsheader -f width $1)
height=$(vipsheader -f height $1)
size=$((width > height ? width : height))
factor=$(bc <<< "scale=10; $max_size / $size")

new_name=$(sed 's/\.jpg/_new\.jpg/' <<< "$1")

vips resize $1 $new_name $factor