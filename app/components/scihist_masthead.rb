class ScihistMasthead < ApplicationComponent
  attr_reader :suppress_product_subhead

  # @param suppress_product_subhead [Boolean] (false) If true, omit the sub-head
  # with "Digital Collections" and a search bar. Used on home page, or other pages that
  # may provide this content and functionality in other ways?
  def initialize(suppress_product_subhead: false)
    @suppress_product_subhead = suppress_product_subhead
  end

end
