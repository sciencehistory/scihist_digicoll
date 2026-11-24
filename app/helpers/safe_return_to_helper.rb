# Included in ApplicationController too, so available in controllers and views.
module SafeReturnToHelper
  # Validates a user-supplied path to redirect to later, e.g. a `return_to` param.
  #
  # Only local paths, so it can't be used to redirect off-site (open redirect):
  # must start with "/" but not "//" (protocol-relative URL), no backslash (some
  # browsers treat it as "/"), and no control chars (header injection).
  # A #fragment is fine, e.g. to return to a spot on the page.
  #
  # @param path [String, nil] usually params[:return_to]
  # @return [String, nil] path if safe, otherwise nil, including for nil or ""
  def safe_return_to(path)
    path if path.is_a?(String) && path.start_with?("/") && !path.start_with?("//") &&
      !path.include?("\\") && !path.match?(/[[:cntrl:]]/)
  end
end
