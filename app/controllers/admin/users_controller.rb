class Admin::UsersController < AdminController
  before_action :set_user, only: [:edit, :update, :send_password_reset]

  before_action do
    authorize! :admin, User
  end

  # GET /users
  # GET /users.json
  def index
    @user_types_map = User.user_types.map{|k, v| [k, v.humanize.pluralize]}.to_h
    @filter = params[:filter] || 'Current'
    if @filter == 'All'
      @users = User.order(:email)
    elsif @user_types_map.values.include? @filter
      @users = User.where(locked_out: false, user_type: @user_types_map.key(@filter)).order(:email)
    else
      @users = User.where(locked_out: false).order(:email)
    end
  end

  # GET /users/new
  def new
    @user = User.new
  end

  # GET /users/1/edit
  def edit
  end

  # POST /users
  # POST /users.json
  def create
    @user = User.new(user_params)

    respond_to do |format|
      if @user.save
        format.html { redirect_to admin_users_path, notice: 'User was successfully created.' }
        format.json { render :show, status: :created, location: @user }
      else
        format.html { render :new }
        format.json { render json: @user.errors, status: :unprocessable_content }
      end
    end
  end

  # PATCH/PUT /users/1
  # PATCH/PUT /users/1.json
  def update
    respond_to do |format|
      if @user.update(user_params)
        format.html { redirect_to admin_users_path, notice: "User #{@user.email} was successfully updated." }
        format.json { render :show, status: :ok, location: @user }
      else
        format.html { render :edit }
        format.json { render json: @user.errors, status: :unprocessable_content }
      end
    end
  end

  # POST /admin/users/:id/send_password_reset
  def send_password_reset
    raise "This method should be unreachable." if ScihistDigicoll::Env.lookup(:log_in_using_microsoft_sso)
    @user.send_reset_password_instructions
    redirect_to admin_users_path, notice: "Password reset email sent to #{@user.email}"
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_user
      @user = User.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def user_params
      params.require(:user).permit(:email, :name, :user_type, :locked_out)
    end
end
