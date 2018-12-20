# Managers UI for creating and editing works.
#
# Started with generated code from Rails 5.2 scaffold.
#
# We'll probably handle `show` in a different controller, for now no show.
class WorksController < ApplicationController
  before_action :set_work, only: [:show, :edit, :update, :destroy, :members_index]

  # GET /works
  # GET /works.json
  def index
    # weird ransack param, we want it to default to true
    if params.dig(:q, "parent_id_null").nil?
      params[:q] ||= {}
      params[:q]["parent_id_null"] = true
    end
    @q = Work.ransack(params[:q])
    @q.sorts = 'updated_at desc' if @q.sorts.empty?

    @works = @q.result.page(params[:page]).per(20)
  end


  # GET /works/new
  def new
    @work = Work.new
  end

  # GET /works/1/edit
  def edit
  end

  # POST /works
  # POST /works.json
  def create
    @work = Work.new(work_params)

    respond_to do |format|
      if @work.save
        format.html { redirect_to works_path, notice: 'Work was successfully created.' }
        format.json { render :show, status: :created, location: @work }
      else
        format.html { render :new }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /works/1
  # PATCH/PUT /works/1.json
  def update
    respond_to do |format|
      if @work.update(work_params)
        format.html { redirect_to works_path, notice: 'Work was successfully updated.' }
        format.json { render :show, status: :ok, location: @work }
      else
        format.html { render :edit }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /works/1
  # DELETE /works/1.json
  def destroy
    @work.destroy
    respond_to do |format|
      format.html { redirect_to works_url, notice: "Work '#{@work.title}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # List all members, which could be Works or Assets
  def members_index
  end

  # triggered from members reorder form,
  #
  # A) Accessed with HTTP put (meaning Rails fakes it with :method hidden field),
  # we want an array of member IDs (UUIDs)
  # in params[:ordered_member_ids][]. All with the same parent, the one specified
  # in params[:id].
  #
  # B) Accessed via HTTP get without params[:ordered_member_ids], we'll sort
  # alphbetically.
  def members_reorder
    if params[:ordered_member_ids]
      params[:ordered_member_ids].each_with_index do |id, index|
        ActiveRecord::Base.transaction do
          Kithe::Model.find(id).update(position: index)
        end
      end
    else # alphabetical
      work = Work.find_by_friendlier_id(params[:id])
      work.members.sort_by(&:title).each_with_index do |member, index|
        ActiveRecord::Base.transaction do
          member.update(position: index)
        end
      end
    end

    redirect_to members_for_work_url(params[:id])
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_work
      @work = Work.find_by_friendlier_id!(params[:id])
    end

    # only allow whitelisted params through (TODO, we're allowing all work params!)
    # Plus sanitization or any other mutation.
    #
    # This could be done in a form object or otherwise abstracted, but this is good
    # enough for now.
    def work_params
      params.require(:work).permit!.tap do |params|
        # sanitize description
        if params[:description].present?
          params[:description] = DescriptionSanitizer.new.sanitize(params[:description])
        end
      end
    end
end
