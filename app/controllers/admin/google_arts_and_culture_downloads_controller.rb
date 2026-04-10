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

    cs = params.dig('load_into_cart', 'created_at_start_date' )
    ms = params.dig('load_into_cart', 'modified_at_start_date')
    ce = params.dig('load_into_cart', 'created_at_end_date'   )
    me = params.dig('load_into_cart', 'modified_at_end_date'  )

    scope = scope.where('DATE(created_at) >= ?', cs.to_date ) if cs.present?
    scope = scope.where('DATE(updated_at) >= ?', ms.to_date ) if ms.present?
    scope = scope.where('DATE(created_at) <= ?', ce.to_date ) if ce.present?
    scope = scope.where('DATE(updated_at) <= ?', me.to_date ) if me.present?

    all_ids = scope.pluck('id')
    CartItem.transaction do
      all_ids.each_slice(500) do |ids|
        CartItem.upsert_all( ids.map { |id| { user_id: current_user.id, work_id: id } } ,  unique_by: [:user_id, :work_id])
      end
    end
    redirect_to admin_google_arts_and_culture_downloads_path, notice: "Added #{scope.count} works to your cart."
  end


  def export_cart
    user_notes = params.dig('export_cart', 'user_notes')
    GoogleArtsAndCultureDownloadCreatorJob.perform_later(user: current_user, user_notes: user_notes)
    redirect_to admin_google_arts_and_culture_downloads_path, notice: "Currently preparing a new download based on the works. Reload this page to see progress."
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
      where("json_attributes -> 'rights'     ?| array[:rights ]", rights:  ['http://creativecommons.org/publicdomain/mark/1.0/'] )

      museum_scope.or(library_scope)
    end
  end
  helper_method :eligible_scope

end
