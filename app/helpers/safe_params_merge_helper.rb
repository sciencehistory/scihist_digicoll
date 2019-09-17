module SafeParamsMergeHelper

  # sometimes we want to take the current Rails action, and change just a handful
  # of params in it, to link or redirect.
  #
  # This is surprisingly hard to do in a secure way, because if the query params
  # have, say, a `host` key, that can end up being an argument sent to `url_for`,
  # allowing the user to change the hosts in your urls. Or if sending to `redirect_to`,
  # a `notice` param in the query params could let the user set flash notice!
  #
  # For this reason, rails will warn you if you just try to do eg
  # `redirect_to params.merge(something: "else"). Rails really wants
  # you to _whitelist_ anything you want preserved from incoming params. But
  # sometimes, especially with Blacklight, we really do want to safely take
  # "all" the incoming params (including ones set from the path by routing!),
  # but with some changed.
  #
  # This is an attempt to do so safely, by insisting on `only_path: true`
  # so host/protocol/etc params will be ignored, and returning a String
  # (So it can't have params interepted as args if passed to redirect_to).
  # Hopefully it works.
  #
  # @example in view safe_params_merge_url(sort: "new_sort")
  # @example in controller you can use helpers.safe_params_merge_url(sort: "new_sort")
  def safe_params_merge_url(to_be_merged)
    url_for(params.to_unsafe_h.merge(to_be_merged.merge(only_path: true)))
  end
end
