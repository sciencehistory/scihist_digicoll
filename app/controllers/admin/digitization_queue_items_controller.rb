class Admin::DigitizationQueueItemsController < AdminController
  before_action :set_admin_digitization_queue_item,
    only: [:show, :edit, :update, :destroy, :add_comment, :delete_comment, :destroy, :export_attached_works_to_cart, :import_attached_works_from_cart]

  # GET /admin/digitization_queue_items
  # GET /admin/digitization_queue_items.json
  def index
    @admin_digitization_queue_items = filtered_index_items
  end

  # GET /admin/digitization_queue_items/1
  # GET /admin/digitization_queue_items/1.json
  def show
  end

  # GET /admin/digitization_queue_items/new
  def new
    @admin_digitization_queue_item = Admin::DigitizationQueueItem.new
  end

  # GET /admin/digitization_queue_items/1/edit
  def edit
  end

  # POST /admin/digitization_queue_items
  # POST /admin/digitization_queue_items.json
  def create
    @admin_digitization_queue_item = Admin::DigitizationQueueItem.new(admin_digitization_queue_item_params)
    respond_to do |format|
      if @admin_digitization_queue_item.save
        # send an alert if email address is set
        if ScihistDigicoll::Env.lookup(:digitization_queue_alerts_email_address)
          DigitizationQueueMailer.with(digitization_queue_item: @admin_digitization_queue_item).new_item_email.deliver_later
        end
        format.html { redirect_to admin_digitization_queue_items_url, notice: 'Digitization queue item was successfully created.' }
        format.json { render :show, status: :created, location: admin_digitization_queue_items_url(@admin_digitization_queue_item) }
      else
        format.html { render :new }
        format.json { render json: @admin_digitization_queue_item.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /admin/digitization_queue_items/1
  def destroy
    respond_to do |format|
      if  @admin_digitization_queue_item.works.size > 0
        # can't delete; there can stil be a race condition where just get an
        # exception without a nice error message, but that's good enough.
        notice = "Can't delete Digitization Queue Item with attached works"
        format.html { redirect_to @admin_digitization_queue_item, notice: notice }
        format.json { render json: { notice: notice } }
      else
        @admin_digitization_queue_item.destroy!
        format.html { redirect_to admin_digitization_queue_items_url(@admin_digitization_queue_item), notice: "Digitization queue item was successfully destroyed." }
        format.json { head :no_content }
      end
    end
  end

  # PATCH/PUT /admin/digitization_queue_items/1
  # PATCH/PUT /admin/digitization_queue_items/1.json
  def update
    respond_to do |format|
      if update_with_action_comments(@admin_digitization_queue_item, admin_digitization_queue_item_params)
        notice = 'Digitization queue item was successfully updated.'
        format.html { redirect_to @admin_digitization_queue_item, notice: notice }
        format.json { render json: { notice: notice } }
      else
        format.html { render :edit }
        format.json { render json: @admin_digitization_queue_item.errors, status: :unprocessable_content }
      end
    end
  end

  # GET /admin/digitization_queue_items/collecting_areas
  # Just lists our top-level collecting areas
  def collecting_areas
    @open_counts = Admin::DigitizationQueueItem.open_status.group(:collecting_area).count
  end

  def collecting_area
    @admin_digitization_queue_item.try(:collecting_area) || params.dig(:query, "collecting_area")
  end
  helper_method :collecting_area

  # POST /admin/digitization_queue_item/1/add_comment
  def add_comment
    if params["comment"].present?
      Admin::QueueItemComment.create!(
        user: current_user,
        digitization_queue_item: @admin_digitization_queue_item,
        text: params["comment"]
      )
    end

    redirect_to @admin_digitization_queue_item
  end

  # admin_delete_comment
  # DELETE
  # /admin/digitization_queue_items/:id/delete_comment/:comment_id(.:format)
  # admin/digitization_queue_items#delete_comment
  def delete_comment
    comment = Admin::QueueItemComment.find_by_id(params['comment_id'])
    raise ArgumentError.new( 'Could not find this comment.') if comment.nil?
    if can?(:destroy, comment)
      comment.delete
      notice = 'Comment deleted.'
    else
      notice = 'You may not delete this comment.'
    end
    redirect_to @admin_digitization_queue_item,
      notice: notice
  end



  # Add all attached works to my cart"
  def export_attached_works_to_cart
    current_user_id = current_user.id
    row_attributes = @admin_digitization_queue_item.works.pluck(:id).map {|work_id| {work_id: work_id, user_id: current_user_id} }
    CartItem.transaction do
      CartItem.upsert_all( row_attributes, unique_by: [:user_id, :work_id])
    end
    redirect_to @admin_digitization_queue_item, notice: "#{row_attributes.count} works were added to your cart."
  end


  # Replace currently attached works with the contents of my cart"
  def import_attached_works_from_cart
    @admin_digitization_queue_item.work_ids = current_user.works_in_cart.pluck(:id)
    @admin_digitization_queue_item.save!
    redirect_to @admin_digitization_queue_item, notice: "#{current_user.works_in_cart.count} works from your cart have been attached."
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin_digitization_queue_item
      @admin_digitization_queue_item = Admin::DigitizationQueueItem.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def admin_digitization_queue_item_params
      params.require(:admin_digitization_queue_item).permit(
        :title, :status, :accession_number, :museum_object_id, :bib_number, :location,
        :box, :folder, :dimensions, :copyright_status,
        :scope, :additional_notes, :collecting_area, :deadline,
        :is_digital_collections, :is_rights_and_reproduction
      )
    end

    def filtered_index_items
      scope = Admin::DigitizationQueueItem.order(deadline: :asc)

      scope = scope.where(collecting_area: collecting_area) if collecting_area.present?

      if (q = params.dig(:query, :q)).present?
        scope = scope.where("title like ? OR bib_number = ? or accession_number = ? OR museum_object_id = ?", "%#{q}%", q, q, q)
      end

      status = params.dig(:query, :status)
      if status == "ANY"
        # no-op, no filter
      elsif status.blank? # default, "open"
        scope = scope.open_status
      else
        scope = scope.where(status: status)
      end


      scope.page(params[:page]).per(100)
    end

    # hacky helper to give us select menu options for status filter
    #
    # The 'nil' option is actually 'closed', that we want to be default
    def status_filter_options
      helpers.options_for_select([["Any", "ANY"]], params.dig(:query, :status)) +
      helpers.grouped_options_for_select(
        { "open/closed" => [["Open", ""], ["Closed", "closed"]],
          "status" =>  Admin::DigitizationQueueItem::STATUSES.
            find_all {|s| s != "closed" }.
            collect {|s| [s.humanize, s]}
        },
        params.dig(:query, :status) || ""
      )
    end
    helper_method :status_filter_options

    # one way to make sure after we save a queue item, it gets a comment
    # recorded for status changes,in the same transaction, without using
    # AR callbacks (and so we have access to current_user)
    #
    # with_action_comments do
    #    save_a_queue_item
    # end
    def update_with_action_comments(queue_item, params)
      result = nil
      queue_item.class.transaction do
        result = queue_item.update(params)
        if result && queue_item.saved_change_to_status?
          queue_item.queue_item_comments.create!(system_action: true, user: current_user, text: "marked: #{queue_item.status.humanize.downcase}")
        end
      end
      result
    end
end
