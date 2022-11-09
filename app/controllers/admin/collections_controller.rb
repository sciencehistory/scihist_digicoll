class Admin::CollectionsController < AdminController
  before_action :set_collection, only: [:show, :edit, :update, :destroy]

  # GET /collections
  # GET /collections.json
  def index
    @q = Collection.ransack(params[:q]).tap do |ransack|
      ransack.sorts = 'title asc' if ransack.sorts.empty?
    end

    scope = @q.result
    if params[:title_or_id].present?
      scope = scope.where(id: params[:title_or_id]
      ).or(
        Collection.where(friendlier_id: params[:title_or_id])
      ).or(
        Collection.where("title ilike ?", "%" + Collection.sanitize_sql_like(params[:title_or_id]) + "%")
      )
    end

    if params[:department].present?
      scope = scope.where("json_attributes ->> 'department' = :department", department: params[:department])
      @department =  params[:department]
    end

    @collections = scope.page(params[:page]).per(100)
  end

  # GET /collections/1
  # GET /collections/1.json
  def show
  end

  # GET /collections/new
  def new
    @collection = Collection.new
  end

  # GET /collections/1/edit
  def edit
  end

  # POST /collections
  # POST /collections.json
  def create
    @collection = Collection.new(collection_params)
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

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_collection
      @collection = Collection.find_by_friendlier_id!(params[:id])
    end

    # only allow whitelisted params through (TODO, we're allowing all collection params!)
    # Plus sanitization or any other mutation.
    #
    # This could be done in a form object or otherwise abstracted, but this is good
    # enough for now.
    def collection_params
      permitted_attributes = [:title, :description, :department]
      permitted_attributes << :published if can?(:publish, @collection || Collection)

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
