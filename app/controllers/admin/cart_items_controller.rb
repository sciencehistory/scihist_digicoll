class Admin::CartItemsController < AdminController
  before_action :authenticate_user! # need to be logged in

  # GET /admin/cart_items
  # GET /admin/cart_items.json
  def index
    # order by when it was added to cart descending i guess
    @works = current_user.works_in_cart.
      with_representative_derivatives.
      page(params[:page]).per(20).
      order("cart_items.created_at desc")
  end


  # PATCH/PUT /admin/cart_items/dj52w562t
  # PATCH/PUT /admin/cart_items/dj52w562t.json
  #
  # Adds or removes a work identified by friendlier_id from logged-in user's cart.
  # If params["toggle"] is sent as `1` will be added, otherwise removed.
  #
  # Used for JS-powered checkbox to add/remove from cart, in CartControl ViewModel with associated JS.
  #
  # ONLY returns a JSON response, no HTML response available, this is for support of our cart add/remove
  # JS.
  def update
    work = Work.find_by_friendlier_id(params[:work_friendlier_id])

    if params[:toggle] == "1"
      current_user.works_in_cart << work
    elsif work
      # delete it, if the work doesn't exist, consider it deleted.
      current_user.works_in_cart.delete(work)
    end

    respond_to do |format|
      format.json do
        render json: {
          cart_count: current_user.works_in_cart.count
        }
      end
    end
  end





  # DELETE /admin/cart_items/dj52w562t
  # DELETE /admin/cart_items/dj52w562t.json
  #
  # Removes a work specified by friendlier_id from cart.
  # This is for our ordinary non-JS 'remove' link on cart page, see also #update used
  # by JS.
  def destroy
    work = Work.find_by_friendlier_id(params[:work_friendlier_id])
    if work
      current_user.works_in_cart.delete(work)
    end

    respond_to do |format|
      format.html { redirect_to admin_cart_items_url, notice: 'Removed item from cart.' }
      format.json { head :no_content }
    end
  end

  def clear
    current_user.works_in_cart.delete_all

    redirect_to admin_cart_items_url, notice: "emptied cart"
  end

end
