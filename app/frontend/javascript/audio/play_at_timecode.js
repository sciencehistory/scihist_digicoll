async function playFromOffset(player, seconds) {
  player.preload = "metadata";

  if (player.readyState < HTMLMediaElement.HAVE_METADATA) {
    player.load();

    await new Promise((resolve, reject) => {
      const cleanup = () => {
        player.removeEventListener("loadedmetadata", onMeta);
        player.removeEventListener("error", onError);
      };
      const onMeta = () => { cleanup(); resolve(); };
      const onError = () => { cleanup(); reject(player.error); };

      player.addEventListener("loadedmetadata", onMeta, { once: true });
      player.addEventListener("error", onError, { once: true });
    });
  }

  player.currentTime = seconds;

  await new Promise(resolve => {
    if (!player.seeking) return resolve();
    player.addEventListener("seeked", resolve, { once: true });
  });

  return player.play();
}

document.addEventListener("DOMContentLoaded", () => {
  const timestampLinks = document.querySelectorAll('*[data-ohms-timestamp-s]');
  const player = document.querySelector("*[data-role=now-playing-container] audio, .show-video video");

  timestampLinks.forEach(element => {
    element.addEventListener('click', async (event) => {
      var seconds = event.target.dataset.ohmsTimestampS;      
      try {
        await playFromOffset(player, seconds);
      } catch (err) {
        console.log("Could not play from offset:", err);
      }

    });
  });
});