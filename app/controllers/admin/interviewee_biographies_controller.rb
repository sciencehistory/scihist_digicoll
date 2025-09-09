class Admin::IntervieweeBiographiesController < AdminController
  before_action :set_interviewee_biography, only: [:edit, :update, :destroy]

  # GET /admin/interviewee_biographies
  def index
    scope = if params[:q].present?
      IntervieweeBiography.by_name params[:q]
    else
      IntervieweeBiography
    end
    @interviewee_biographies = scope.order(:name).page(params[:page]).per(100).all
  end

  # GET "/admin/interviewee_biographies/new"
  def new
    @interviewee_biography = IntervieweeBiography.new
  end

  # GET /admin/interviewee_biographies/1/edit
  def edit
  end

  # POST /admin/interviewee_biographies
  def create
    @interviewee_biography = IntervieweeBiography.new(interviewee_biography_params)

    respond_to do |format|
      if @interviewee_biography.save
        format.html { redirect_to admin_interviewee_biographies_path, notice: 'Interviewee biography was successfully created.' }
        format.json { render :edit, status: :created, location: @interviewee_biography }
      else
        format.html { render :new }
        format.json { render json: @interviewee_biography.errors, status: :unprocessable_content }
      end
    end

  end


  # PATCH/PUT /admin/interviewee_biographies/1
  def update
    respond_to do |format|
      if @interviewee_biography.update(interviewee_biography_params)
        format.html { redirect_to admin_interviewee_biographies_path, notice: 'Interviewee biography was successfully updated.' }
        format.json { render :edit, status: :ok, location: @interviewee_biography }

        # Associated works need to be reindexed on some Biography changes, but that isn't
        # triggered automatically in model callbacks. We handle it here. There should only be one or two,
        # so no problem to do it inline.
        @interviewee_biography.oral_history_content&.collect(&:work)&.each(&:update_index)
      else
        format.html { render :edit }
        format.json { render json: @interviewee_biography.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /admin/interviewee_biographies/1
  def destroy
    @interviewee_biography.destroy
    respond_to do |format|
      format.html { redirect_to admin_interviewee_biographies_url, notice: 'Interviewee biography was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private

  # Use callbacks to share common setup or constraints between actions.
    def set_interviewee_biography
      @interviewee_biography = IntervieweeBiography.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def interviewee_biography_params
      tmp =  Kithe::Parameters.new(params).require(:interviewee_biography).permit_attr_json(IntervieweeBiography).permit(:name)

      %w{school job honor}.each do |name|
        tmp["#{name}_attributes"]&.reject! { |k, v| v.values.all?(&:empty?) }
      end

      tmp.delete("birth_attributes") if tmp["birth_attributes"].blank?
      tmp.delete("death_attributes") if tmp["death_attributes"].blank?

      %w{birth death school job honor}.each do |name|
        tmp["#{name}_attributes"]&.permit!
      end

      # HTML Sanitize the "honor" entry. Hacky code.
      (tmp["honor_attributes"] || []).each do |honor_attributes|
        next unless honor_attributes.dig(1, "honor")
        honor_attributes[1]["honor"] = DescriptionSanitizer.new.sanitize(honor_attributes[1]["honor"])
      end

      tmp
    end

end
