require "byebug"

# Checks a single property in a Fedora item.
class FedoraPropertyChecker
  def initialize(old_val:, new_val:, flag:, fedora_id:, order_matters:)
    @old_val = old_val
    @new_val = new_val
    @flag = flag
    @order_matters = order_matters
    @fedora_id = fedora_id
  end

  def check()
    return if compare(@old_val, @new_val)
    """ERROR: #{@fedora_id} ===> #{@flag}
        Fedora:
          #{@old_val}
        Scihist:
          #{@new_val}"""
  end

  # Tests for equivalency between a and b.
  def compare(a, b)
    if (a.is_a? Array) && (b.is_a? Array)
      return compare_arrays(a, b)
    end
    compare_scalars(a, b)
  end

  #Compare two arrays.
  def compare_arrays(a, b)
    # Compare as an array if order matters:
    return a == b if @order_matters
    # Compare as a set otherwise:
    a.to_set == b.to_set
  end

  # For our purposes, if an item is
  # nil in Fedora and "" in scihist_digicoll,
  # or vice-versa, that's fine.
  def compare_scalars(a, b)
    x = a.present? ? a : nil
    y = b.present? ? b : nil
    x == y
  end
end