# Display a checkbox to add or remove all works on the page to the current user's cart.
# See also cart_control.js and cart_items_controller.rb
class CartControlComponentMultiple < ApplicationComponent
  attr_reader :work_friendlier_ids, :start_checked

  def initialize(work_friendlier_ids, start_checked: false, label_sr_only: false)
    @work_friendlier_ids = work_friendlier_ids
    @start_checked = start_checked
    @label_sr_only = label_sr_only
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
        " ",
        label_tag('check-or-uncheck-all-works', "Check or uncheck all works on this page", class: ("sr-only" if @label_sr_only))
      ])
    end
  end
end