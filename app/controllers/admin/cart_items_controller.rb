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


  # # POST /admin/cart_items
  # # POST /admin/cart_items.json
  # def create
  #   @admin_cart_item = Admin::CartItem.new(admin_cart_item_params)

  #   respond_to do |format|
  #     if @admin_cart_item.save
  #       format.html { redirect_to @admin_cart_item, notice: 'Cart item was successfully created.' }
  #       format.json { render :show, status: :created, location: @admin_cart_item }
  #     else
  #       format.html { render :new }
  #       format.json { render json: @admin_cart_item.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # PATCH/PUT /admin/cart_items/1
  # PATCH/PUT /admin/cart_items/1.json
  # def update
  #   respond_to do |format|
  #     if @admin_cart_item.update(admin_cart_item_params)
  #       format.html { redirect_to @admin_cart_item, notice: 'Cart item was successfully updated.' }
  #       format.json { render :show, status: :ok, location: @admin_cart_item }
  #     else
  #       format.html { render :edit }
  #       format.json { render json: @admin_cart_item.errors, status: :unprocessable_entity }
  #     end
  #   end
  # end

  # DELETE /admin/cart_items/dj52w562t
  # DELETE /admin/cart_items/dj52w562t.json
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
