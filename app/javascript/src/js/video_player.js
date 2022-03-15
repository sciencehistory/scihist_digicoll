import videojs from 'video.js';


// Get video.js styles via webpack
// https://docs.videojs.com/tutorial-webpack.html
require('!style-loader!css-loader!video.js/dist/video-js.css')


// video js plugins? With CSS loaded?
require("videojs-seek-buttons");
require("!style-loader!css-loader!videojs-seek-buttons/dist/videojs-seek-buttons.css");

