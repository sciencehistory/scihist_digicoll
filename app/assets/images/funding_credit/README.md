These are images for use with the Collection "FundingCredit" information.

See ./app/models/funding_credit.rb.

For now, instead of allowing staff to upload images for "funding credit", we
just hard-code them app source, in a constnat in FundingCredit, with images living here.

* JPG or PNG is fine.

*  No transparent backgrounds in PNGs though please -- or, I mean, there can be transparent bg around the outside of a shape, that's fine. But one of those examples was just WORDS on a transaparent background, which isn't going to work well if the background color showing through the transaprency is too close in color to the words! Transparent bg only that will work with arbitrary bg color showing through the transparency, if you want to think about it.

* Not sure I am sure about exactly how many pixels the image should be, but I'm going to say 224x224px? (that's enough for 2x resolution at our "standard" size). A little bit bigger is probably fine, but not a lot smaller, and definitely no smaller than 112px x 112px (1x resolution at our 'standard' size).

Once you add an image to source here, you reference it's path in the IMAGES constant in FundingCredit please.

This is hacky, but we're not going to use this feature very much probably, it works for now.

### Optomizing/minimizing images

The kinds of images we use for logos should be very compressable without noticeable image quality loss. It makes sense to try to make the image as small in file size as it can be.

Some images may be smaller as PNG or as JPG depending on nature of image.

Also you can run images through the `imagemin` CLI util to do some standard file reduction (may want to start with a larger or non-lossy copy as source, but it probably doesn't matter much for most logo images).

https://github.com/imagemin/imagemin-cli

https://web.dev/use-imagemin-to-compress-images/
