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

    @works = @q.result.includes(:derivatives).includes(:leaf_representative => :derivatives).page(params[:page]).per(20)
  end


  # GET /works/new
  def new
    @work = Work.new
    if params[:parent_id]
      @parent_work = Work.find_by_friendlier_id!(params[:parent_id])
      @work.parent = @parent_work
      @work.contained_by = @parent_work.contained_by
      @work.position = (@parent_work.members.maximum(:position) || 0) + 1
    end

    render :edit
  end

  # GET /works/1/edit
  def edit
  end

  # POST /works
  # POST /works.json
  def create
    @work = Work.new(work_params)

    if @work.parent_id && @work.position.nil?
      @work.position = (@work.parent.members.maximum(:position) || 0) + 1
    end

    respond_to do |format|
      if @work.save
        format.html { redirect_to work_path(@work), notice: 'Work was successfully created.' }
        format.json { render :show, status: :created, location: @work }
      else
        format.html { render :edit }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /works/1
  # PATCH/PUT /works/1.json
  def update
    respond_to do |format|
      if @work.update(work_params)
        format.html { redirect_to work_path(@work), notice: 'Work was successfully updated.' }
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
      format.html { redirect_to cancel_url, notice: "Work '#{@work.title}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # Our admin 'show' page is really the members index.
  def show
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
      ActiveRecord::Base.transaction do
        params[:ordered_member_ids].each_with_index do |id, index|
          Kithe::Model.find(id).update(position: index)
        end
      end
    else # alphabetical
      work = Work.find_by_friendlier_id(params[:id])
      sorted_members = work.members.sort_by{ |member| member.title.downcase  }.to_a
      ActiveRecord::Base.transaction do
        sorted_members.each_with_index do |member, index|
          member.update(position: index)
        end
      end
    end

    redirect_to work_url(params[:id])
  end


  private
    # Use callbacks to share common setup or constraints between actions.
    def set_work
      @work = Work.includes(:leaf_representative).find_by_friendlier_id!(params[:id])
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

    def cancel_url
      if @work && @work.parent
        return work_path(@work.parent)
      end

      if @work && @work.persisted?
        return work_path(@work)
      end

      works_path
    end
    helper_method :cancel_url
end
