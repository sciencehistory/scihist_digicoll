# Display a checkbox for adding something and removing someting from admin 'cart'. The checkbox
# will be powered by Javascript.
class CartControl < ViewModel
  attr_reader :work_friendlier_id, :cart_presence
  def initialize(work_friendlier_id, cart_presence:)
    @work_friendlier_id = work_friendlier_id
    @cart_presence = cart_presence
  end

  def display
    form_tag(admin_cart_item_path(work_friendlier_id),
              class: "cart-toggle-form",
              method: :put) do
      safe_join([
        check_box_tag("toggle",
          "1",
          already_in_cart?,
          id: input_id,
          data: { "cart-toggle-input" => true }
         ),
        " ",
        label_tag(input_id, "In Cart")
      ])
    end
  end

  private

  def already_in_cart?
    cart_presence.in_cart?(work_friendlier_id)
  end

  def input_id
    "cartToggle-#{work_friendlier_id}"
  end
end
