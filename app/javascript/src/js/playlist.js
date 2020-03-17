/*
   An audio player with playlist below, where clicking on an item from the playlist
   loads in audio player (and starts playing). When one track finishes, starts playing
   the next automatically.
*/
$( document ).ready(function() {

	function SciHistAudioPlaylist(playlistWrapper) {
		this.playlistWrapper = $(playlistWrapper);
		this.audioElement    = this.findByRole('ohms-audio-elem')[0];
		this.playlistWrapper.on("click", "[data-role='play-link']", this.onTrackClick.bind(this));
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
		var startTime = $(track).data('startTime');
		if (startTime != -1) {
			this.audioElement.currentTime = startTime;
		}
	};

	$("[data-role='audio-playlist-wrapper']").each(function() {
		new SciHistAudioPlaylist(this);
	});
 });
