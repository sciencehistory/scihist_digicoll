# Display a checkbox to add or remove all works on the page to the current user's cart.
# See also cart_control.js and cart_items_controller.rb
class CartControlComponentMultiple < ApplicationComponent
  attr_reader :work_friendlier_ids

  def initialize(work_friendlier_ids)
    @work_friendlier_ids = work_friendlier_ids
  end

  def call
    form_tag(admin_update_multiple_cart_items_path(work_friendlier_ids),
              class: "multiple-cart-toggle-form",
              method: :post) do
      safe_join([
        check_box_tag("toggle",
          "1",
          data: { "multiple-cart-toggle-input" => true }
         ),
        " "
      ])
    end
  end
end
