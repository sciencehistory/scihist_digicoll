class Admin::InterviewerProfilesController < AdminController
  before_action :set_admin_interviewer_profile, only: [:edit, :update, :destroy]

  # GET /admin/interviewer_profiles
  # GET /admin/interviewer_profiles.json
  def index
    @admin_interviewer_profiles = Admin::InterviewerProfile.order(:name).all
  end


  # GET /admin/interviewer_profiles/new
  def new
    @admin_interviewer_profile = Admin::InterviewerProfile.new
  end

  # GET /admin/interviewer_profiles/1/edit
  def edit
  end

  # POST /admin/interviewer_profiles
  # POST /admin/interviewer_profiles.json
  def create
    @admin_interviewer_profile = Admin::InterviewerProfile.new(admin_interviewer_profile_params)

    respond_to do |format|
      if @admin_interviewer_profile.save
        format.html { redirect_to @admin_interviewer_profile, notice: 'Interviewer profile was successfully created.' }
        format.json { render :show, status: :created, location: @admin_interviewer_profile }
      else
        format.html { render :new }
        format.json { render json: @admin_interviewer_profile.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/interviewer_profiles/1
  # PATCH/PUT /admin/interviewer_profiles/1.json
  def update
    respond_to do |format|
      if @admin_interviewer_profile.update(admin_interviewer_profile_params)
        format.html { redirect_to @admin_interviewer_profile, notice: 'Interviewer profile was successfully updated.' }
        format.json { render :show, status: :ok, location: @admin_interviewer_profile }
      else
        format.html { render :edit }
        format.json { render json: @admin_interviewer_profile.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /admin/interviewer_profiles/1
  # DELETE /admin/interviewer_profiles/1.json
  def destroy
    @admin_interviewer_profile.destroy
    respond_to do |format|
      format.html { redirect_to admin_interviewer_profiles_url, notice: 'Interviewer profile was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_admin_interviewer_profile
      @admin_interviewer_profile = Admin::InterviewerProfile.find(params[:id])
    end

    # Only allow a list of trusted parameters through.
    def admin_interviewer_profile_params
      params.require(:admin_interviewer_profile).permit(:name, :profile)
    end
end
