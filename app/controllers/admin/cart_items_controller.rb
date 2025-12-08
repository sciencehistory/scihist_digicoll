class Admin::CartItemsController < AdminController
  before_action :authenticate_user! # need to be logged in
  require 'csv'


  # GET /admin/cart_items
  # GET /admin/cart_items.json
  def index
    # order by when it was added to cart descending i guess
    @works = current_user.works_in_cart.
      includes(:leaf_representative).
      page(params[:page]).per(20).
      order("cart_items.created_at desc")
  end


  # PATCH/PUT /admin/cart_items/dj52w562t
  # PATCH/PUT /admin/cart_items/dj52w562t.json
  #
  # Adds or removes a work identified by friendlier_id from logged-in user's cart.
  # If params["toggle"] is sent as `1` will be added, otherwise removed.
  #
  # Used for JS-powered checkbox to add/remove from cart, in CartControlComponent with associated JS.
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


  # POST /admin/cart_items/update_multiple/:list_of_ids(.:format)  admin/cart_items#add_multiple
  def update_multiple

    unless ["1", "0"].include? params[:toggle]
      raise ArgumentError, "params[:toggle] must be 0 or 1."
    end

    Work.transaction do
      works = Work.where friendlier_id: params[:list_of_ids].split(',')
      if params[:toggle] == "1"
        current_user.works_in_cart = Set.new(works + current_user.works_in_cart)
      else
        current_user.works_in_cart -= works
      end
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

  def report
    begin
      serializer = WorkCartSerializer.new(current_user.works_in_cart)
      output_csv_file = serializer.csv_tempfile
      send_file output_csv_file.path, filename: "cart-report-#{Date.today.to_s}.csv"
    ensure
      output_csv_file.close
    end
  end


  def google_arts_and_culture_export
    begin
      serializer = GoogleArtsAndCulture::Exporter.new(current_user.works_in_cart)
      output_csv_file = serializer.metadata_csv_tempfile
      send_file output_csv_file.path, filename: "google-arts-and-culture-export-#{Date.today.to_s}.csv"
    ensure
      output_csv_file.close
    end
  end
end
