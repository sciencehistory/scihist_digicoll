We use these AWS MediaConvert Presets for transcoding video and creating HLS streaming copies.

AWS MediaConvert does not have a terraform adapter. But it does let you export these presets as JSON and later import them again.

Should you ever need to re-create presets, you can take these json files and import them at https://us-east-1.console.aws.amazon.com/mediaconvert/home?region=us-east-1#/presets/details/scihist-hls-high

You should name based on filename without the `aws-mediaconvert-preset-` prefix, eg `scihist-hls-high`, `scihist-hls-medium` and `scihist-hls-low`. Our app code may expect presets at certain names.

To change presets, go ahead and edit them in the AWS dashboard, and then just re-export and commit here please to save a record of our current settings.

See also [Wiki page doccumenting our HLS/MediaConvert feature](https://sciencehistory.atlassian.net/l/c/MXeDCSjw)

And some discussion of preset choices at https://github.com/sciencehistory/scihist_digicoll/issues/1693
