// We have a checkbox for admins for adding/removing Works from the 'cart'. The checkbox is provided by
// CartControlComponent
//
// This JS turns it into an auto-submit form, and handles errors, and updating the cart item count.
//
// Uses JQuery.

jQuery( document ).ready(function( $ ) {

  function form_disable(form) {
    form.find(".cart-checkbox, label").attr("disabled", "disabled");
  }

  function form_enable(form) {
    form.find(".cart-checkbox, label").removeAttr("disabled");
  }

  function multiple_form_disable(form) {
    form.find(".cart-multiple-checkbox, label").attr("disabled", "disabled");
  }

  function multiple_form_enable(form) {
    form.find(".cart-multiple-checkbox, label").removeAttr("disabled");
  }


  // SINGLE work cart checkbox:
  $(document).on("change", ".cart-checkbox", function(event) {
    var checkbox = $(this);
    var form = checkbox.closest("form");

    $.ajax({
        url: form.attr('action'),
        dataType: 'json',
        type: form.attr('method').toUpperCase(),
        data: form.serialize(),
        beforeSend: function() {
          form_disable(form);
        },
        error: function(xhr, ajaxOptions, error) {
          console.error("cart item toggle error\r\n" + error + "\r\n" + xhr.statusText + "\r\n" + xhr.responseText);
          // Revert the checkbox change
          checkbox.prop("checked", !checkbox.prop("checked"));
          alert("Error in cart item modify");
          form_enable(form)
        },
        success: function(data, status, xhr) {
          //if app isn't running at all, xhr annoyingly
          //reports success with status 0, so non-0 we consider success.
          if (xhr.status != 0) {
            // update cart count
            $("span[data-role=cart-counter]").text(data["cart_count"]);
            form_enable(form);
          } else {
            console.error("cart item toggle error\r\n" + error + "\r\n" + xhr.statusText + "\r\n" + xhr.responseText);
            // Revert the checkbox change
            checkbox.prop("checked", !checkbox.prop("checked"));
            alert("Error in cart item modify");
            form_enable(form)
          }
        }
    });
  });

  // MULTIPLE work cart checkbox:

  $(document).on("change", ".cart-multiple-checkbox", function(event) {
    var checkbox = $(this);
    var form = checkbox.closest("form");


    $.ajax({
        url: form.attr('action'),
        dataType: 'json',
        type: form.attr('method').toUpperCase(),
        data: form.serialize(),

        beforeSend: function() {
          multiple_form_disable(form);
        },
        
        error: function(xhr, ajaxOptions, error) {
          console.error("Multiple cart item toggle error\r\n" + error + "\r\n" + xhr.statusText + "\r\n" + xhr.responseText);
          // Revert the checkbox change
          checkbox.prop("checked", !checkbox.prop("checked"));
          alert("Error in cart item modify");
          multiple_form_enable(form)
        },

        success: function(data, status, xhr) {
          //Set all the checkboxes to the same status as this one:
          $('.cart-checkbox').each(function() {$(this).prop("checked", checkbox.prop("checked"))})

          //if app isn't running at all, xhr annoyingly
          //reports errors with status 0, so non-0 we consider success.
          if (xhr.status != 0) {
            // update cart count
            $("span[data-role=cart-counter]").text(data["cart_count"]);
            multiple_form_enable(form);
          } else {
            console.error("cart item toggle error\r\n" + error + "\r\n" + xhr.statusText + "\r\n" + xhr.responseText);
            // Revert the checkbox change
            checkbox.prop("checked", !checkbox.prop("checked"));
            alert("Error in cart all");
            multiple_form_enable(form)
          }
        }
    });
  });
});
