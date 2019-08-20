class Admin::DigitizationQueueItemsController < AdminController
  before_action :set_admin_digitization_queue_item, only: [:show, :edit, :update, :destroy, :add_comment, :delete_comment]

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
        format.html { redirect_to admin_digitization_queue_items_url(@admin_digitization_queue_item.collecting_area), notice: 'Digitization queue item was successfully created.' }
        format.json { render :show, status: :created, location: admin_digitization_queue_items_url(@admin_digitization_queue_item.collecting_area) }
      else
        format.html { render :new }
        format.json { render json: @admin_digitization_queue_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/digitization_queue_items/1
  # PATCH/PUT /admin/digitization_queue_items/1.json
  def update
    respond_to do |format|
      if update_with_action_comments(@admin_digitization_queue_item, admin_digitization_queue_item_params)
        format.html { redirect_to @admin_digitization_queue_item, notice: 'Digitization queue item was successfully updated.' }
        format.json { render text: "Something" }
      else
        format.html { render :edit }
        format.json { render json: @admin_digitization_queue_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /admin/digitization_queue_items/collecting_areas
  # Just lists our top-level collecting areas
  def collecting_areas
    @open_counts = Admin::DigitizationQueueItem.open_status.group(:collecting_area).count
  end

  # DELETE /admin/digitization_queue_items/1
  # DELETE /admin/digitization_queue_items/1.json
  # def destroy
  #   @admin_digitization_queue_item.destroy
  #   respond_to do |format|
  #     format.html { redirect_to admin_digitization_queue_items_url(collecting_area), notice: 'Digitization queue item was successfully destroyed.' }
  #     format.json { head :no_content }
  #   end
  # end

  def collecting_area
    @admin_digitization_queue_item.try(:collecting_area) || params.fetch(:collecting_area)
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
  # /admin/digitization_queue_items/delete_comment/:comment_id(.:format)
  # admin/admin/digitization_queue_items#delete_comment

  def delete_comment
    comment = Admin::QueueItemComment.find_by_id(params['comment_id'])

    if comment.nil?
      redirect_to @admin_digitization_queue_item,
        notice: 'Could not find this comment.'
      return
    end

    # This is also checked on the front end -
    # just being paranoid.
    #
    # TODO use standard permissions:
    # unless can?(:delete, comment)
    if current_user.id != comment.user_id
      redirect_to @admin_digitization_queue_item,
        notice: "You may not delete this comment."
      return
    end

    comment.delete
    redirect_to @admin_digitization_queue_item,
      notice: 'Comment deleted.'
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
        :box, :folder, :dimensions, :materials, :copyright_status,
        :scope, :instructions, :additional_notes, :collecting_area
      )
    end

    def filtered_index_items
      scope = Admin::DigitizationQueueItem.where(collecting_area: collecting_area).order(status_changed_at: :asc)

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

      # helpers.options_for_select(
      #   Admin::DigitizationQueueItem::STATUSES.
      #     find_all {|s| s != "closed" }.
      #     collect {|s| [s.humanize, s]},
      #   params.dig(:query, :status)
      # )
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
