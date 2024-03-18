// When book reader modal opens, set it's iframe src to the book reader
$('#scihist-bookreader-viewer-modal').on('show.bs.modal', function (e) {
  const iframe = document.getElementById("scihist-bookreader-viewer-iframe");
  if (iframe['src'] == '') {
    iframe['src'] = iframe.dataset.frameSrc;
  }
});
