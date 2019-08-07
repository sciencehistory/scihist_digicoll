// heavily adapted from shrine-rails-example single "cover" photo.
// https://github.com/erikdahlstrand/shrine-rails-example
//
// Just a single file with something that looks like a file input. Used in collections/_form

import domready from 'domready';

// We are just using Uppy loaded from CDN in script tag, only in admin layout.
// If we actually had it as a dependency in webpacker, we'd want:
//import Uppy from 'uppy';

domready(function() {
  const fileUpload = function(fileInput) {
    fileInput.style.display = 'none' // uppy will add its own file input

    var uploadEndpoint   = fileInput.getAttribute("data-upload-endpoint");
    var s3Storage        = fileInput.getAttribute("data-s3-storage");
    var s3StoragePrefix  = fileInput.getAttribute("data-s3-storage-prefix");
    var previewDiv       = fileInput.closest(".form-group").querySelector("*[data-toggle=scihist-simple-uppy-file-preview]");
    var hiddenInput      = fileInput.closest(".form-group").querySelector("*[data-toggle=scihist-simple-uppy-file-hidden]");

    var uppy = Uppy.Core({
      id: fileInput.id,
      autoProceed: true,
      restrictions: {
        allowedFileTypes: fileInput.accept.split(','),
        maxNumberOfFiles: 1
      }
    })
    .use(Uppy.FileInput, {
      target: fileInput.parentNode,
      locale: {
        strings: {
          chooseFiles: "Select new file"
        }
      }
    })
    .use(Uppy.Informer, {
      target: fileInput.parentNode,
    })
    .use(Uppy.ProgressBar, {
      target: fileInput.parentNode,
    });

    if (s3Storage) {
      uppy.use(Uppy.AwsS3Multipart, {
        companionUrl: (uploadEndpoint || '/') // will call Shrine's presign endpoint mounted on `/s3/params`
      })
    } else {
      uppy.use(Uppy.XHRUpload, {
        endpoint: (uploadEndpoint || "/direct_upload"), // Shrine's upload endpoint
        fieldName: 'file'
      })
    }

    const shrineHiddenFieldValue = function(file, response) {
      var shrineHash;

      if (s3Storage) {
        var url = new URL(response.uploadURL);
        var shrineId = url.pathname.replace(/^\//, '') // remove leading slash on pathname
        if (s3StoragePrefix) {
          // object key is path on s3, but without the configured shrine storage prefix,
          // get the part after our storage prefix.
          var s3StoragePrefixNoTrailingSlash = s3StoragePrefix.replace(/\/$/, "");
          shrineId = shrineId.match(new RegExp('^' + s3StoragePrefixNoTrailingSlash + '\/([^\?]+)'))[1];
        }

        shrineHash = {
          id: shrineId,
          storage: s3Storage,
          metadata: {
            size:      file.size,
            filename:  file.name,
            mime_type: file.type,
          }
        }
      } else {
        shrineHash = response.body;
      }

      return JSON.stringify(shrineHash);
    };

    uppy.on('upload', (data) => {
      if(previewDiv) {
        previewDiv.innerHTML = `<p class='text-danger'>Please wait while we store file...</p>`;
      }
    });

    uppy.on('upload-success', function (file, data) {
      hiddenInput.value = shrineHiddenFieldValue(file, data);
      if(previewDiv) {
        previewDiv.innerHTML = `<p>Will be saved: ${file.name}</p>`;
      }
    });
  };




  document.querySelectorAll('input[type=file][data-toggle=scihist-simple-uppy-file]').forEach(function (fileInput) {
    fileUpload(fileInput)
  });


});
