# Display a checkbox to add or remove all works on the page to the current user's cart.
# See also cart_control.js and cart_items_controller.rb
class CartControlComponentMultiple < ApplicationComponent
  attr_reader :work_friendlier_ids, :start_checked

  def initialize(work_friendlier_ids, start_checked: false)

    # Comma-separated list of friendlier_ids for works to either check or uncheck:
    @work_friendlier_ids = work_friendlier_ids

    # Whether to display the checkbox as checked when the page loads:
    @start_checked = start_checked
  end

  def call
    form_tag(admin_update_multiple_cart_items_path(work_friendlier_ids),
              class: "multiple-cart-toggle-form",
              method: :post) do
      safe_join([
        check_box_tag("toggle",
          "1",
          @start_checked,
          id: 'check-or-uncheck-all-works',
          data: { "multiple-cart-toggle-input" => true },
          class: "cart-multiple-checkbox"
         ),
        " "
      ])
    end
  end
end