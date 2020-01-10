class Admin::RAndRItemsController < AdminController
  before_action :set_admin_r_and_r_item, only: [:show, :edit, :update, :destroy]

  # GET /admin/r_and_r_items
  # GET /admin/r_and_r_items.json
  def index
    @admin_r_and_r_items = r_and_r_items
  end

  # GET /admin/r_and_r_items/1
  # GET /admin/r_and_r_items/1.json
  def show
  end

  # GET /admin/r_and_r_items/new
  def new
    @admin_r_and_r_item = Admin::RAndRItem.new
  end

  # GET /admin/r_and_r_items/1/edit
  def edit
  end

  # POST /admin/r_and_r_items/create
  # POST /admin/r_and_r_items/create.json
  def create
    @admin_r_and_r_item = Admin::RAndRItem.new(admin_r_and_r_item_params)

    respond_to do |format|
      if @admin_r_and_r_item.save
        format.html { redirect_to admin_r_and_r_item_path(@admin_r_and_r_item), notice: 'R&R item was successfully created.' }
        format.json { render :show, status: :created, location: admin_r_and_r_items_url(@admin_r_and_r_item.collecting_area) }
      else
        format.html { render :new }
        format.json { render json: @admin_r_and_r_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/r_and_r_items/1
  # PATCH/PUT /admin/r_and_r_items/1.json
  def update
    respond_to do |format|
      if @admin_r_and_r_item.update(admin_r_and_r_item_params)
        format.html { redirect_to @admin_r_and_r_item, notice: 'R&R item updated.' }
        format.json { render text: "Something" }
      else
        format.html { render :edit }
        format.json { render json: @admin_r_and_r_item.errors, status: :unprocessable_entity }
      end
    end
  end

  # GET /admin/r_and_r_items/collecting_areas
  # Just lists our top-level collecting areas
  def collecting_areas
    @open_counts = Admin::RAndRItem.open_status.group(:collecting_area).count
  end

  # DELETE /admin/r_and_r_items/1
  # DELETE /admin/r_and_r_items/1.json
  def destroy
    @admin_r_and_r_item.destroy
    respond_to do |format|
      format.html { redirect_to admin_r_and_r_items_url(collecting_area), notice: 'R&R item was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def collecting_area
    @admin_r_and_r_item.try(:collecting_area) # || params.fetch(:collecting_area)
  end
  helper_method :collecting_area

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin_r_and_r_item
      @admin_r_and_r_item = Admin::RAndRItem.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def admin_r_and_r_item_params
      params.require(:admin_r_and_r_item).permit(
        :title, :status, :accession_number, :museum_object_id, :bib_number, :location,
        :box, :folder, :dimensions, :materials, :copyright_status,
        :scope, :instructions, :additional_notes, :collecting_area,
        :is_destined_for_ingest, :copyright_research_still_needed, :curator, :patron_name,
        :patron_email, :deadline, :date_files_sent,
        :additional_pages_to_ingest
      )
    end

    def r_and_r_items
      scope = Admin::RAndRItem.order(status_changed_at: :asc)


      # if (q = params.dig(:query, :q)).present?
      #   scope = scope.where("title like ? OR bib_number = ? or accession_number = ? OR museum_object_id = ?", "%#{q}%", q, q, q)
      # end

      # status = params.dig(:query, :status)
      # if status == "ANY"
      #   # no-op, no filter
      # elsif status.blank? # default, "open"
      #   scope = scope.open_status
      # else
      #   scope = scope.where(status: status)
      # end

      scope.page(params[:page]).per(100)
    end

    def filtered_index_items
      scope = Admin::RAndRItem.
        where(collecting_area: collecting_area).
        order(status_changed_at: :asc)

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
          "status" =>  Admin::RAndRItem::STATUSES.
            find_all {|s| s != "closed" }.
            collect {|s| [s.humanize, s]}
        },
        params.dig(:query, :status) || ""
      )

      # helpers.options_for_select(
      #   Admin::RAndRItem::STATUSES.
      #     find_all {|s| s != "closed" }.
      #     collect {|s| [s.humanize, s]},
      #   params.dig(:query, :status)
      # )
    end
    helper_method :status_filter_options
end
