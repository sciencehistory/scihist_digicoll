# Managers UI for creating and editing works.
#
# Started with generated code from Rails 5.2 scaffold.
#
# We'll probably handle `show` in a different controller, for now no show.
class Admin::WorksController < AdminController
  before_action :set_work,
    only: [:show, :edit, :update, :destroy, :reorder_members,
           :reorder_members_form, :demote_to_asset, :publish, :unpublish,
           :submit_ohms_xml, :create_combined_audio_derivatives]

  # GET /admin/works
  # GET /admin/works.json
  def index
    @q = ransack_object
    @works = index_work_search(@q)
    @cart_presence = CartPresence.new(@works.collect(&:friendlier_id), current_user: current_user)
  end


  # GET /admin/works/new
  def new
    @work = Work.new

    if params[:digitization_queue_item]
      queue_item = Admin::DigitizationQueueItem.find(params[:digitization_queue_item])
      @work.digitization_queue_item_id = queue_item.id
      queue_item.fill_out_work(@work)
    end

    if params[:parent_id]
      @parent_work = Work.find_by_friendlier_id!(params[:parent_id])

      if @parent_work.genre &&
        @parent_work.genre.include?('Oral histories') &&
        @parent_work.published?
        redirect_to admin_work_url(params[:parent_id], anchor: "nav-members"),
          alert: "Please unpublish '#{@parent_work.title}' if you want to add a child work to it."
        return
      end

      @work.parent = @parent_work
      @work.contained_by = @parent_work.contained_by
      @work.position = (@parent_work.members.maximum(:position) || 0) + 1
    end

    render :edit
  end

  # GET /admin/works/1/edit
  def edit
  end

  # POST /admin/works
  # POST /admin/works.json
  def create
    @work = Work.new(work_params)

    if @work.parent_id && @work.position.nil?
      @work.position = (@work.parent.members.maximum(:position) || 0) + 1
    end

    respond_to do |format|
      if @work.save
        format.html { redirect_to admin_asset_ingest_path(@work), notice: 'Work was successfully created, would you like to add files now?' }
        format.json { render :show, status: :created, location: @work }
      else
        format.html { render :edit }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /admin/works/1
  # PATCH/PUT /admin/works/1.json
  def update
    respond_to do |format|
      if @work.update(work_params)
        format.html { redirect_to admin_work_path(@work), notice: 'Work was successfully updated.' }
        format.json { render :show, status: :ok, location: @work }
      else
        format.html { render :edit }
        format.json { render json: @work.errors, status: :unprocessable_entity }
      end
    end
  end

  # comes in as a file multipart POST, we read it and stick it in ohms_xml text field please
  # PATCH/PUT /admin/works/ab2323ac/submit_ohms_xml
  def submit_ohms_xml
    unless params[:ohms_xml].present?
      redirect_to admin_work_path(@work, anchor: "nav-oral-histories"), flash: { error: "No file received" }
      return
    end

    xml = params[:ohms_xml].read
    validator = OralHistoryContent::OhmsXmlValidator.new(xml)

    if validator.valid?
      @work.oral_history_content!.update!(ohms_xml_text: xml)
      redirect_to admin_work_path(@work, anchor: "nav-oral-histories"), notice: "OHMS XML file updated"
    else
      Rails.logger.debug("Could not accept invalid OHMS XML for work #{@work.friendlier_id}:\n  #{xml.slice(0, 60).gsub(/[\n\r]/, '')}...\n\n  #{validator.errors.join("\n  ")}")
      redirect_to admin_work_path(@work, anchor: "nav-oral-histories"), flash: { error: "OHMS XML file was invalid and could not be accepted!" }
    end
  end


  # Create_combined_audio_derivatives in the background, if warranted.
  # PATCH/PUT /admin/works/ab2323ac/create_combined_audio_derivatives
  # Unfortunately, if the job fails for any reason, the user will not be notified.
  def create_combined_audio_derivatives
    CreateCombinedAudioDerivativesJob.perform_later(@work)
    notice = "The combined audio derivative job has been launched."
    redirect_to admin_work_path(@work, anchor: "nav-oral-histories"), notice: notice
  end


  # PATCH/PUT /admin/works/1/publish
  #
  # publishes work AND all of it's children (multi-level).
  #
  # fetches all children so rails callbacks will be called, but uses postgres
  # recursive CTE so it'll be efficient-ish.
  def publish
    authorize! :publish, @work

    if need_combined_audio_derivatives?
      error = "Combined audio derivatives are absent or out of date. Please generate them before publishing this work."
      redirect_to admin_work_path(@work, anchor: "nav-members"), flash: { error: error }
      return
    end

    @work.class.transaction do
      @work.update!(published: true)
      @work.all_descendent_members.find_each do |member|
        member.update!(published: true)
      end
    end

    redirect_to admin_work_url(@work)
  rescue ActiveRecord::RecordInvalid => e
    # probably because missing a field required for a work to be published, but
    # could apply to a CHILD work, not just the parent you actually may have clicked 'publish'
    # on.
    #
    # The work we're going to report and redirect to is just the FIRST one we encountered
    # with an error, there could be more.
    @work = e.record
    @work.published = true
    flash.now[:error] = "Can't publish work: #{@work.title}: #{e.message}"
    render :edit
  end

  # PUT /admin/works/1/unpublish
  #
  # unpublishes work AND all of it's children (multi-level) using a pg recursive CTE
  #
  # fetches all children so rails callbacks will be called, but uses postgres
  # recursive CTE so it'll be efficient-ish.
  def unpublish
    authorize! :publish, @work

    @work.class.transaction do
      @work.update!(published: false)
      @work.all_descendent_members.find_each do |member|
        member.update!(published: false)
      end
    end

    redirect_to admin_work_url(@work)
  end

  # DELETE /works/1
  # DELETE /works/1.json
  def destroy
    authorize! :destroy, @work

    @work.destroy
    respond_to do |format|
      format.html { redirect_to cancel_url, notice: "Work '#{@work.title}' was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  # Our admin 'show' page is really the members index.
  def show
    @cart_presence = CartPresence.new([@work.friendlier_id], current_user: current_user)
  end

  def reorder_members_form
    # For oral histories, don't allow the manual reorder_members_form to be displayed if the work is published.
    if work_is_oral_history? && @work.published?
      redirect_to admin_work_url(params[:id], anchor: "nav-members"),
        alert: "Please unpublish '#{@work.title}' if you want to reorder the interview segments."
      return
    end
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
  def reorder_members
    # For oral histories, don't allow automatic alphabetical reordering of
    # members if the work is published
    # (this would invalidate their combined audio derivatives.)
    work = Work.find_by_friendlier_id!(params[:id])
    if  work_is_oral_history? && work.published?
      redirect_to admin_work_url(params[:id], anchor: "nav-members"),
        alert: "Please unpublish '#{work.title}' if you want to reorder the interview segments."
      return
    end

    if params[:ordered_member_ids]
      ActiveRecord::Base.transaction do
        params[:ordered_member_ids].each_with_index do |id, index|
          Kithe::Model.find(id).update(position: index)
        end
      end
    else # alphabetical
      sorted_members = work.members.sort_by{ |member| member.title.downcase  }.to_a
      ActiveRecord::Base.transaction do
        sorted_members.each_with_index do |member, index|
          member.update(position: index)
        end
      end
    end

    redirect_to admin_work_url(params[:id], anchor: "nav-members")
  end

  def self.can_demote_to_asset?(work)
    work.parent.present? &&
      work.parent.kind_of?(Work) &&
      work.members.size == 1 &&
      work.members.first.kind_of?(Asset)
  end

  def demote_to_asset
    unless self.class.can_demote_to_asset?(@work)
      redirect_to admin_work_path(@work), alert: "Can't convert this work to an Asset"
      return
    end

    parent = @work.parent
    # a bit of race condition here if someone else added an asset in the meantime,
    # it'll be lost. no big deal at present, unclear right way to solve.
    #
    # Also surprisingly hard to make sure rails doesn't delete the asset when we
    # delete the parent, even though we've re-homed the asset, due to dependent destroy. grr.
    # The reset says we'll get the first right from db, without a cached list of members,
    # and it'll refetch list of members later for dependent destroy. :(
    asset = @work.members.reset.first

    asset.position = @work.position
    asset.parent = @work.parent

    Kithe::Model.transaction do
      if parent.representative_id == @work.id
        parent.representative = asset
        parent.save!
      end

      asset.save!
      @work.destroy
    end

    redirect_to admin_work_path(asset.parent, anchor: "nav-members"), notice: "Child work replaced with asset #{asset.title}"
  end

  # Display a form for entry for batch editing all works in Cart. Convenient
  # to put it in WorksController so we can re-use our work form partials.
  def batch_update_form
    # just a dummy blank one to power the form, the BatchUpdateWorkForm
    # object will remove 'presence' validators so the form won't show any
    # fields as required.
    @work = Admin::BatchUpdateWorkForm.new({})
  end

  # Accepts input from batch_update_form, to apply to all items in cart.
  def batch_update
    @work = Admin::BatchUpdateWorkForm.new(work_params)

    unless @work.update_works(current_user.works_in_cart.find_each)
      # the form is based on @work, so re-rendered will show errors
      render :batch_update_form
      return
    end

    redirect_to admin_cart_items_url, notice: "Updated works in Cart"
    return

    ####

    unless @work.valid?
      render :batch_update_form
      return
    end

    update_attrs = Work.attr_json_registry.definitions.reduce({}) do |hash, attr_defn|
      value = @work.send(attr_defn.name)
      if value.present?
        hash[attr_defn.name] = value
      end
      hash
    end

    Work.transaction do
      current_user.works_in_cart.find_each do |work|
        update_attrs.each do |k, v|
          if v.kind_of?(Array)
            work.send("#{k}=", work.send(k) + v)
          else
            work.send("#{k}=", v)
          end

          unless work.valid?
            @work.errors.add(:base, "#{work.title} (#{work.friendlier_id}): #{work.errors.full_messages.join(', ')}")
            flash.now[:error] = "Some works in the cart couldn't be saved, they may have pre-existing problems. The batch update was not done."
            render :batch_update_form
            return
          end

          work.save!
        end
      end
    end

    redirect_to admin_cart_items_url, notice: "Updated works in Cart"
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
      Kithe::Parameters.new(params).require(:work).permit_attr_json(Work).permit(
        :title, :parent_id, :representative_id, :digitization_queue_item_id, :contained_by_ids => []
      ).tap do |params|
        # sanitize description & provenance
        [:description, :provenance].each do |field|
          if params[field].present?
            params[field] = DescriptionSanitizer.new.sanitize(params[field])
          end
        end
      end
    end

    # Some of our query SQL is prepared by ransack, which automatically makes
    # queries from specially named param fields.  (And also has conveniences
    # for sort UI especially).
    #
    # https://github.com/activerecord-hackery/ransack
    #
    # that includes our sorting, our main text query field, and also
    # 'published' and "include or exclude Child Works that match query"
    #
    # But other things we add on in ordinary AR, see #index_work_search
    def ransack_object
      # weird ransack param, we want it to default to true
      if params.dig(:q, "parent_id_null").nil?
        params[:q] ||= {}
        params[:q]["parent_id_null"] = true
      end

      ransack_obj = Work.ransack(params[:q]).tap do |ransack|
        ransack.sorts = 'updated_at desc' if ransack.sorts.empty?
      end
    end


    # Take a ransack object that already has an ActiveRecord scope
    # with some of our search conditions in it, and add on the ones
    # that were hard to do in Ransack -- mainly the ones that we want
    # to use custom postgres JSON-related operators for.
    #
    # Also add on pagination and any eager-loading.
    def index_work_search(ransack_object)
      scope = ransack_object.result

      if params[:q][:genre].present?
        # fancy postgres json operators, may not be using indexes not sure.
        # genre is actually a JSON array so we use postgres ? operator
        scope = scope.where("json_attributes -> 'genre' ? :genre", genre: params[:q][:genre])
      end

      if params[:q][:format].present?
        scope = scope.where("json_attributes -> 'format' ? :format", format: params[:q][:format])
      end

      if params[:q][:department].present?
        scope = scope.where("json_attributes ->> 'department' = :department", department: params[:q][:department])
      end

      scope.with_representative_derivatives.page(params[:page]).per(20)
    end

    def cancel_url
      if @work && @work.parent
        return admin_work_path(@work.parent, anchor: "admin-nav")
      end

      if @work && @work.persisted?
        return admin_work_path(@work, anchor: "admin-nav")
      end

      admin_works_path
    end
    helper_method :cancel_url

    def work_is_oral_history?
      @work.genre && @work.genre.include?('Oral histories')
    end
    helper_method :work_is_oral_history?

    # If this work is an oral history,
    # return true if the user needs to
    # (re)calculate combined audio derivatives.
    # before the work can be published.
    def need_combined_audio_derivatives?
      # Not an oral history? Then you don't need these derivatives.
      return false unless work_is_oral_history?
      # Now, are they up to date?
      existing_fingerprint = @work.oral_history_content!.combined_audio_fingerprint
      (existing_fingerprint != CombinedAudioDerivativeCreator.new(@work).fingerprint)
    end

    def restrict_audio_member_edit?(member)
      return false if member.work?
      return false unless @work.published?
      member.content_type && member.content_type.start_with?('audio')
    end
    helper_method :restrict_audio_member_edit?


    # Certain edits to oral histories
    # are prohibited if the work is published.
    # This mostly happens here in the controller,
    # but as a courtesy we're also trying not to display
    # certain parts of the UI that would result in an
    # error message anyway.
    def ok_to_edit_this_member?(member)
      # Restrictions only apply to oral histories.
      return true unless work_is_oral_history?
      # If the oral history isn't published, you can edit it.
      return true unless @work.published?
      # Also, child works are fine to edit -- they wouldn't affect the OHMS metadata.
      return true if member.work?
      # But you need to unpublish it if
      return false
    end
    helper_method :ok_to_edit_this_member?

end
