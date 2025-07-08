class Admin::CollectionsController < AdminController
  before_action :set_collection, only: [:show, :edit, :update, :destroy]
  before_action :sort_link_maker, only: [:index]

  # GET /collections
  # GET /collections.json
  def index
    # No authorize! call here to filter viewable items in the list.
    # We're assuming if you can view the index, you can see all published and
    # unpublished collections.

    # Searching, filtering, sorting and pagination.
    scope = Collection.strict_loading.includes(:leaf_representative)
    if index_params[:title_or_id].present?
      sanitized_search_phrase = Collection.sanitize_sql_like params[:title_or_id]

      # Match on the `value` of external_id, regardless of `category`.
      jsonb_match_value = "'[{\"value\": \"#{sanitized_search_phrase}\"}]'::jsonb"
      matches_external_id = "json_attributes -> 'external_id' @> #{jsonb_match_value}"

      scope = scope.where(id: index_params[:title_or_id]
      ).or(
        Collection.strict_loading.where(friendlier_id: index_params[:title_or_id])
      ).or(
        Collection.strict_loading.where("title ilike ?", "%" + sanitized_search_phrase + "%")
      ).or(
        Collection.strict_loading.where matches_external_id
      )
    end

    if index_params[:department].present?
      scope = scope.where("json_attributes ->> 'department' = :department", department: index_params[:department])
      @department =  index_params[:department]
    end

    scope.order(index_params[:sort_field] => index_params[:sort_order])
    @collections = scope.page(index_params[:page]).per(100)
  end

  # Set up click-to-sort column headers.
  def sort_link_maker
    @sort_link_maker ||= SortedTableHeaderLinkComponent.link_maker params: index_params
  end
  helper_method :sort_link_maker

  # GET /collections/1
  # GET /collections/1.json
  def show
    authorize! :read, @collection
  end

  # GET /collections/new
  def new
    @collection = Collection.new
    authorize! :create, @collection
  end

  # GET /collections/1/edit
  def edit
    authorize! :update, @collection
  end

  # POST /collections
  # POST /collections.json
  def create
    @collection = Collection.new(collection_params)
    authorize! :create, @collection
    respond_to do |format|
      if @collection.save
        format.html { redirect_to admin_collections_url, notice: "Collection '#{@collection.title}' was successfully created." }
        format.json { render :show, status: :created, location: @collection }
      else
        format.html { render :new }
        format.json { render json: @collection.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /collections/1
  # PATCH/PUT /collections/1.json
  def update
    authorize! :update, @collection
    respond_to do |format|
      if @collection.update(collection_params)
        format.html { redirect_to collection_url(@collection), notice: "Collection '#{@collection.title}' was successfully updated." }
        format.json { render :show, status: :ok, location: @collection }
      else
        format.html { render :edit }
        format.json { render json: @collection.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /collections/1
  # DELETE /collections/1.json
  def destroy
    authorize! :destroy, @collection

    @collection.destroy
    respond_to do |format|
      format.html { redirect_to admin_collections_url, notice: "Collection '#{@collection.title}' was successfully deleted." }
      format.json { head :no_content }
    end
  end

  def representative
    @collection&.representative
  end
  helper_method :representative

  def representative_is_image?
    representative.file.present? && representative&.content_type&.start_with?("image/")
  end
  helper_method :representative_is_image?

  def representative_dimensions_correct?
    representative.width.present? &&
    representative.height.present? &&
    representative.width == representative.height &&
    representative.width >= CollectionThumbAsset::COLLECTION_PAGE_THUMB_SIZE * 2
  end
  helper_method :representative_dimensions_correct?


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_collection
      @collection = Collection.find_by_friendlier_id!(params[:id])
    end

    # Params method just for #index.
    # Also sets default sort column and order, and
    # sanitizes all strings used in sorting and filtering.
    def index_params
      @index_params ||= params.permit(
        :sort_field, :sort_order, :department, :page, :title_or_id, :button,
      ).tap do |hash|
        hash[:sort_field] = "title" unless hash[:sort_field].in? ['title', 'created_at', 'updated_at']
        hash[:sort_order] = "asc"   unless hash[:sort_order].in? ['asc', 'desc']
        if hash[:department].present?
          unless hash[:department].in?(Collection::DEPARTMENTS)
            raise ArgumentError.new("Unrecognized department: #{hash[:department]}")
          end
        end
      end
    end

    # only allow whitelisted params through (TODO, we're allowing all collection params!)
    # Plus sanitization or any other mutation.
    #
    # This could be done in a form object or otherwise abstracted, but this is good
    # enough for now.
    def collection_params
      permitted_attributes = [:title, :description, :department, :default_sort_field]
      permitted_attributes << :published if can?(:publish, @collection || Kithe::Model)

      Kithe::Parameters.new(params).
        require(:collection).
        permit(*permitted_attributes,
                :representative_attributes => {},
                :funding_credit_attributes => {},
                :related_link_attributes => {},
                :external_id_attributes => true
        ).tap do |hash|

          # sanitize description
          if hash[:description].present?
            hash[:description] = DescriptionSanitizer.new.sanitize(hash[:description])
          end

          # remove empty representative_attributes so we don't create an empty Asset on that association
          # if we had nothing submitted, we still leave representative set though
          if hash[:representative_attributes] && hash[:representative_attributes].values.all?(&:blank?)
            hash.delete(:representative_attributes)
          end

          # if empty funding_credit_attributes, we actually want to delete funding_credit_attributes
          if hash[:funding_credit_attributes] && hash[:funding_credit_attributes].values.all?(&:blank?)
            # force delete of the thing with the actual non-attributes method, yeah, this is a hack.
            hash[:funding_credit] = nil
          end
        end
    end
end
