$( document ).ready(function() {

  // A JS 'class' for handling download UI
  //
  // A link or button witb data elements triggers:
  //     <a href="#"
  //        data-trigger="on-demand-download"
  //        data-work-id="#{work.friendlier_id}"
  //        data-derivative-type="zip_file">
  //
  //  Will result in a progress/status modal if required, eventually
  //  turning into a redirect to derivative download URL.
  //
  //  By accessing the OnDemandDerivativeController endpoint to return
  //  JSON to launch lazy deriv generation if needed, and tell this script
  //  status, and eventually URL location of derivative on successful creation.
  //
  function ScihistOnDemandDownloader(work_id, type) {
    this.work_id = work_id;
    this.deriv_type = type;

    if (!this.work_id || !this.deriv_type) {
      console.error("tried to create ScihistOnDemandDownloader with missing args");
      throw { "work_id": work_id, type: type};
    }
  }

  ScihistOnDemandDownloader.prototype.fetchForStatus = function() {
    var _self = this;

    fetch("/works/" + this.work_id + "/" + _self.deriv_type).then(function(response) {

      return response.json();
    }).then(function(json) {
      if (json.status == "success") {
        if (existing = _self.getModal(true)) {
          existing.modal("hide");
        }
        window.location = json.file_url;
      } else if (json.status == "in_progress") {
        _self.updateProgress(json);
        _self.getModal().modal("show");
        // wait, then check again....
        _self.nextFetch = setTimeout(function() {
          _self.fetchForStatus();
        }, 2000);
      } else {
        json_error = JSON.parse(json.error_info);
        if (json_error) {
          throw json_error.class + ": " + json_error.message;
        } else {
          throw json;
        }
      }
    }).catch(function(error) {
      _self.handleError(error);
    });
  };

  ScihistOnDemandDownloader.prototype.getModal = function(lazy) {
    var _self = this;
    if (_self.modalElement) {
      return _self.modalElement;
    } else if (lazy) {
      return undefined;
    }
    //create a new bootstrap modal
    var modalEl = $('\
      <div class="modal on-demand-download" tabindex="-1" role="dialog" aria-labelledby="onDemandDownloadStatusTitle"> \
        <div class="modal-dialog" role="document">\
          <div class="modal-content">\
            <div class="modal-header">\
              <span class="modal-title" id="onDemandDownloadStatusTitle">Preparing your download</span>\
            </div>\
            <div class="modal-body">\
              <div data-progress-placeholder></div>\
              <p>Large downloads may take some time to prepare. We appreciate your patience.</p>\
            </div>\
            <div class="modal-footer">\
              <button type="button" class="btn btn-primary" data-dismiss="modal">Cancel</button>\
            </div>\
          </div>\
        </div>\
      </div> \
    ');
    $("body").append(modalEl);

    modalEl.modal({
      backdrop: true,
      show: false
    });

    // make sure any fetches get cancelled if modal is cancelled.
    modalEl.on('hidden.bs.modal', function (e) {
      if (_self.nextFetch) {
        clearTimeout(_self.nextFetch);
        _self.nextFetch = null;
      }
      // and destroy the element so we can create a new one later on another
      // click, without interfering. JQuery-based dev is a bit hacky...
      _self.modalElement.remove();
      _self.modalElement = null;
    })

    _self.modalElement = modalEl;

    return _self.modalElement;
  };

  ScihistOnDemandDownloader.prototype.updateProgress = function(json_response) {
    html = "";

    if (json_response.progress && json_response.progress_total && json_response.progress != json_response.progress_total) {
      html = '<div class="progress">' +
                '<div class="progress-bar" role="progressbar" aria-valuemin="0" aria-valuenow="' +
                    json_response.progress + '" aria-valuemax="' + json_response.progress_total + '"' +
                    'style="width: ' + Math.floor((json_response.progress / json_response.progress_total) * 100) + '%;"' +
                    '>' +
                '</div>' +
              '</div>';
    } else if (json_response.progress && json_response.progress_total && json_response.progress == json_response.progress_total) {
      html = '<div class="progress progress-striped active">\
              <div class="progress-bar"  role="progressbar" aria-valuenow="100" aria-valuemin="0" aria-valuemax="100" style="width: 100%">' +
              ' Finishing... ' +
              '</div>' +
            '</div>';
    } else {
      html = '<div class="progress progress-striped active">\
              <div class="progress-bar"  role="progressbar" aria-valuenow="100" aria-valuemin="0" aria-valuemax="100" style="width: 100%">' +
              '</div>\
            </div>';
    }
    this.getModal().find("*[data-progress-placeholder]").html(html);
  };

  ScihistOnDemandDownloader.prototype.handleError = function(error) {
    console.log("Error fetching on-demand derivative: " + error);
    this.getModal().find(".modal-body").html(
      '<h1 class="h2"><i class="fa fa-warning text-danger" aria-hidden="true"></i> A software error occured.</h1>' +
      '<p class="text-danger">We\'re sorry, your download can not be delivered at this time.</p>'
    );
    this.getModal().modal("show");
  };

  $(document).on('click', '*[data-trigger="on-demand-download"]', function(e) {
    e.preventDefault();

    var type = $(e.target).data("derivative-type");
    var id   = $(e.target).data("work-id");

    var downloader = new ScihistOnDemandDownloader(id, type);
    downloader.fetchForStatus();
  });
});
