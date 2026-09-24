# Admin feature to search-and-replace a value in a single Work metadata field,
# across ALL Works (not scoped to cart/collection). See Admin::BatchReplaceMetadataForm
# for the actual logic and field configuration.
class Admin::BatchReplaceMetadataController < AdminController
  # authorize! :update, Work would make more sense here, but we currently aren't
  # allowed to do that -- see Admin::WorksController#batch_update for the same issue
  # (https://github.com/chaps-io/access-granted/pull/56).
  before_action -> { authorize! :update, Kithe::Model }

  def new
    @form = Admin::BatchReplaceMetadataForm.new
  end

  # Shows how many Works match the given search, and the first 50 (or all, with
  # `show_all` param) of them, with a button to actually perform the replacement.
  def preview
    @form = Admin::BatchReplaceMetadataForm.new(form_params)

    unless @form.valid?
      render :new
      return
    end

    @show_all = params[:show_all].present?
    @works_to_list = @show_all ? @form.matching_works : @form.matching_works.first(50)
  end

  def create
    @form = Admin::BatchReplaceMetadataForm.new(form_params)

    unless @form.valid?
      render :new
      return
    end

    count = @form.matching_work_count

    unless @form.replace!
      render :new
      return
    end

    redirect_to admin_works_path, notice: "Replaced metadata in #{count} work#{"s" unless count == 1}. It may take a few minutes for changes to be visible in public search."
  end

  # Params rails-ujs / the browser adds to our form submissions that aren't actual
  # form fields, and so shouldn't be mass-assigned to Admin::BatchReplaceMetadataForm.
  NON_FORM_PARAMS = %i[show_all commit authenticity_token _method].freeze

  private

  def form_params
    params.permit(:field_name, :old_value, :new_value, *NON_FORM_PARAMS).except(*NON_FORM_PARAMS)
  end
end
