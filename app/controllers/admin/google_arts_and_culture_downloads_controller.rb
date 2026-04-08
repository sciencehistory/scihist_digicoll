class Admin::GoogleArtsAndCultureDownloadsController < AdminController
  before_action :authenticate_user!

  def index
    @google_arts_and_culture_downloads = GoogleArtsAndCultureDownload.all
      .includes(:user)
      .page(params[:page]).per(20)
      .order(created_at: :desc)
  end

  # Post to this method to load a bunch of works into the cart
  def load_into_cart

    scope = eligible_scope

    created_at_start_date = params.dig('load_into_cart', 'created_at_start_date')
    scope = scope.where('created_at >= ?', created_at_start_date) if created_at_start_date.present?

    modified_at_start_date = params.dig('load_into_cart', 'modified_at_start_date')
    scope = scope.where('created_at >= ?', modified_at_start_date) if modified_at_start_date.present?

    created_at_end_date =  params.dig('load_into_cart', 'created_at_end_date')
    scope = scope.where('created_at <= ?', created_at_end_date) if created_at_end_date.present?
    
    modified_at_end_date =  params.dig('load_into_cart', 'modified_at_end_date')
    scope = scope.where('created_at <= ?', modified_at_end_date) if modified_at_end_date.present?

    all_ids = scope.pluck('id')

    CartItem.transaction do
      all_ids.each_slice(500) do |ids|
        CartItem.upsert_all( ids.map { |id| { user_id: current_user.id, work_id: id } } ,  unique_by: [:user_id, :work_id])
      end
    end

    redirect_to admin_google_arts_and_culture_downloads_url, notice: "Added #{scope.count} works to your cart."

  end

  def eligible_scope
    @eligible_scope ||= begin

      museum_scope = Work.where(published: true).
      where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Museum'] ).
      where("json_attributes -> 'format'     ?| array[:formats]", formats: ['physical_object'] ).
      where("json_attributes -> 'rights'     ?| array[:rights ]", rights:  ['https://creativecommons.org/licenses/by/4.0/'] )

      library_scope = Work.where(published: true).
      where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Library'] ).
      where("json_attributes -> 'format'     ?| array[:formats]", formats: ['image'] ).
      where("json_attributes -> 'rights'     ?| array[:rights ]", rights:  ['http://creativecommons.org/publicdomain/mark/1.0/'] ).

      museum_scope.or(library_scope)
    end
  end
  helper_method :eligible_scope



end

  # ids_to_include = eligible_scope.pluck(:id)



# w = Work.find(id)

# # Only include library works if they're published between 1450 and 1929
# if w.department == "Library"
#   helper = DateIndexHelper.new(w)
#   earliest = helper.min_date&.year
#   latest =   helper.max_date&.year
#   unless earliest.present? && earliest >= 1450 && latest.present? && latest <= 1929
#     next
#   end
# end

