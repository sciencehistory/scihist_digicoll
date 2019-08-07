/* Somewhat hacky, written by we who aren't great at JS, based on JQuery
   and using an HTML5 audio element.

   An audio player with playlist below, where clicking on an item from the playlist
   loads in audio player (and starts playing). When one track finishes, starts playing
   the next automatically.

   Clicking a track to 'load' it in player also sets download links for currently
   playing track.
*/
$( document ).ready(function() {

	function SciHistAudioPlaylist(playlistWrapper) {
	  this.playlistWrapper = $(playlistWrapper);

	  this.firstTrack 		 = this.findByRole('track-listing')[0];
	  this.audioElement    = this.findByRole('audio-elem')[0];

	  this.audioElement.onended = this.playNextTrack.bind(this);
	  this.playlistWrapper.on("click", "[data-role='play-link']", this.onTrackClick.bind(this));

		this.loadTrack(this.firstTrack);
	};

	SciHistAudioPlaylist.prototype.playNextTrack = function() {
		var nextTrack = this.playlistWrapper.find("[data-currently-selected='true']").next()[0];
		if (nextTrack) {
			this.loadTrack(nextTrack);
			this.playAudio();
		}
	};

	SciHistAudioPlaylist.prototype.onTrackClick = function(ev) {
		ev.preventDefault();
		var trackListing = $(ev.target).closest("[data-role='track-listing']");
		this.loadTrack(trackListing);
		this.playAudio();
	};

	SciHistAudioPlaylist.prototype.findByRole = function(role) {
		return this.playlistWrapper.find("[data-role='" + role + "']");
	};

	SciHistAudioPlaylist.prototype.playAudio = function() {
		// See: https://stackoverflow.com/questions/9421505/switch-audio-source-with-jquery-and-html5-audio-tag
		// oncanplaythrough in case audio isn't fully loaded yet when we call this.
		this.audioElement.oncanplaythrough = this.audioElement.play();
	};

	SciHistAudioPlaylist.prototype.loadTrack = function(track) {
		// css (for styling)
		this.findByRole('track-listing').removeClass("currently-selected");
		$(track).addClass("currently-selected");

		// data attribute (for identifying the item).
		this.findByRole('track-listing').attr('data-currently-selected', 'false');
		$(track).attr('data-currently-selected', 'true');

		this.findByRole('current-track-label').html( $(track).data('title'));

		$(this.audioElement).find("source[type='audio/mpeg']").attr("src", $(track).data('mp3Url'));
		$(this.audioElement).find("source[type='audio/webm']").attr("src", $(track).data('webmUrl'));

		// Tell HTML audio to load new stuff
		// See: https://stackoverflow.com/questions/9421505/switch-audio-source-with-jquery-and-html5-audio-tag
		this.audioElement.pause();
		this.audioElement.load();
	};

	$("[data-role='audio-playlist-wrapper']").each(function() {
		new SciHistAudioPlaylist(this);
	});
 });
