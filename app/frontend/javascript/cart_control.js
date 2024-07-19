// For each work in the admin work list, we display a checkbox that allows an admin user to add it or remove it
// from the user's cart'. The checkbox is provided by CartControlComponent.
// We also provide a convenience checkbox at the bottom of the page that does the same for ALL works on the page.
//
// This JS turns the checkboxes into an auto-submit form, and handles errors, and updates the cart item count.
//
// Uses JQuery.

jQuery( document ).ready(function( $ ) {

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
          formDisable(form);
        },
        error: function(xhr, ajaxOptions, error) {
          console.error("cart item toggle error\r\n" + error + "\r\n" + xhr.statusText + "\r\n" + xhr.responseText);
          // Revert the checkbox change
          checkbox.prop("checked", !checkbox.prop("checked"));
          alert("Error in cart item modify");
          formEnable(form);
        },
        success: function(data, status, xhr) {
          //if app isn't running at all, xhr annoyingly
          //reports success with status 0, so non-0 we consider success.
          if (xhr.status != 0) {
            // update cart count
            updateCount(data["cart_count"]);
            formEnable(form);
          } else {
            console.error("cart item toggle error\r\n" + error + "\r\n" + xhr.statusText + "\r\n" + xhr.responseText);
            // Revert the checkbox change
            checkbox.prop("checked", !checkbox.prop("checked"));
            alert("Error in cart item modify");
            formEnable(form);
          }
        }
    });
  });

  // MULTIPLE work cart checkbox:
  $(document).on("change", ".cart-multiple-checkbox", function(event) {
    var checkbox = $(this);

    $.ajax({
        url:        '/admin/cart_items/update_multiple',
        dataType:   'json',
        type:       'POST',
        data:       { "list_of_ids": checkbox.data('list-of-ids'),
                      "toggle": checkbox.prop("checked") ? 1 : 0
                    },
        
        beforeSend: function() {
          // Disable the checkbox until server confirms the change went through.
          multipleFormDisable();
        },
        
        error: function(xhr, ajaxOptions, error) {
          console.error("Multiple cart item toggle error\r\n" + error + "\r\n" + xhr.statusText + "\r\n" + xhr.responseText);
          // Revert the checkbox change
          checkbox.prop("checked", !checkbox.prop("checked"));
          alert("Unable to add or remove multiple works from your cart.");
          multipleFormEnable();
        },

        success: function(data, status, xhr) {
          if (xhr.status != 0) {
            // SUCCESS

            // Set all the "cart" checkboxes to the same status as this one.
            // This does *not* trigger a 'change' event, because we're using JS to change the value.
            //     "Note: Changing the value of an input element using JavaScript, using .val() for example, won't fire the [change] event"
            //     https://api.jquery.com/change/
            $('.cart-checkbox').each(function() {$(this).prop("checked", checkbox.prop("checked"))})

            updateCount(data["cart_count"]);
            multipleFormEnable();

          } else {
            // FAILURE
            console.error("Error adding or removing multiple works from the user's cart. Details:\r\n" + error + "\r\n" + xhr.statusText + "\r\n" + xhr.responseText);
            // Revert the checkbox change
            checkbox.prop("checked", !checkbox.prop("checked"));
            alert("Unable to add or remove multiple works from your cart.");
            multipleFormEnable();
          }
        }
    });
  });


  // Prevent user from clicking the checkboxes while we wait for the server:
  function formDisable(form, multiple=false) {
    form.find(".cart-checkbox, label").attr("disabled", "disabled");
  }

  function formEnable(form, multiple=false) {
    form.find(".cart-checkbox, label").removeAttr("disabled");
  }

  function multipleFormDisable() {
    document.querySelector('.cart-multiple-checkbox').setAttribute("disabled", "disabled");
    var other_checkboxes = document.querySelectorAll('.cart-checkbox');
    for (var i=0; i < other_checkboxes.length; i++) {
        other_checkboxes[i].setAttribute("disabled", "disabled");
    }
  }

  function multipleFormEnable() {
    document.querySelector('.cart-multiple-checkbox').removeAttribute("disabled");
    var other_checkboxes = document.querySelectorAll('.cart-checkbox');
    for (var i=0; i < other_checkboxes.length; i++) {
        other_checkboxes[i].removeAttribute("disabled");
    }
  }

  function updateCount(number) {
    $("span[data-role=cart-counter]").text(number);
  }

});
