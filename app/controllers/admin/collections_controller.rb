class Admin::CollectionsController < AdminController
  before_action :set_collection, only: [:show, :edit, :update, :destroy]

  # GET /collections
  # GET /collections.json
  def index
    @collections = Collection.all
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
        format.html { redirect_to admin_collections_url, notice: "Collection '#{@collection.title}' was successfully updated." }
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
      permitted_attributes = [:title, :description]
      permitted_attributes << :published if can?(:publish, @collection || Collection)

      params.
        require(:collection).
        permit(*permitted_attributes, :representative_attributes => {}, :related_url_attributes => []).tap do |hash|
          # sanitize description
          if hash[:description].present?
            hash[:description] = DescriptionSanitizer.new.sanitize(hash[:description])
          end

          # remove empty representative_attributes so we don't create an empty Asset on that association
          if hash[:representative_attributes] && hash[:representative_attributes].values.all?(&:blank?)
            hash.delete(:representative_attributes)
          end
        end
    end
end
