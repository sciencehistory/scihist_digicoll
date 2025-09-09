class Admin::InterviewerProfilesController < AdminController
  before_action :set_interviewer_profile, only: [:edit, :update, :destroy]

  # GET /admin/interviewer_profiles
  # GET /admin/interviewer_profiles.json
  def index
    scope = if params[:q].present?
      InterviewerProfile.by_name params[:q]
    else
      InterviewerProfile
    end
    @interviewer_profiles = scope.order(:name).page(params[:page]).per(100).all
  end


  # GET /admin/interviewer_profiles/new
  def new
    @interviewer_profile = InterviewerProfile.new
  end

  # GET /admin/interviewer_profiles/1/edit
  def edit
  end

  # POST /admin/interviewer_profiles
  # POST /admin/interviewer_profiles.json
  def create
    @interviewer_profile = InterviewerProfile.new(interviewer_profile_params)

    respond_to do |format|
      if @interviewer_profile.save
        format.html { redirect_to admin_interviewer_profiles_path, notice: 'Interviewer profile was successfully created.' }
        format.json { render :show, status: :created, location: @interviewer_profile }
      else
        format.html { render :new }
        format.json { render json: @interviewer_profile.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /admin/interviewer_profiles/1
  # PATCH/PUT /admin/interviewer_profiles/1.json
  def update
    respond_to do |format|
      if @interviewer_profile.update(interviewer_profile_params)
        format.html { redirect_to admin_interviewer_profiles_path, notice: 'Interviewer profile was successfully updated.' }
        format.json { render :show, status: :ok, location: @interviewer_profile }
      else
        format.html { render :edit }
        format.json { render json: @interviewer_profile.errors, status: :unprocessable_content }
      end
    end
  end

  # DELETE /admin/interviewer_profiles/1
  # DELETE /admin/interviewer_profiles/1.json
  def destroy
    @interviewer_profile.destroy
    respond_to do |format|
      format.html { redirect_to admin_interviewer_profiles_url, notice: 'Interviewer profile was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_interviewer_profile
      @interviewer_profile = InterviewerProfile.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def interviewer_profile_params
      params.require(:interviewer_profile).permit(:name, :profile).tap do |params|
        # Sanitize desciprion to include only allowed HTML.
        params[:profile] = DescriptionSanitizer.new.sanitize(params[:profile])
      end
    end
end
