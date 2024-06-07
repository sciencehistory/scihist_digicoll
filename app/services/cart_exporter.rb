class CartExporter
  attr_reader :scope

  def initialize(scope, columns: nil)
    @scope = scope
    @columns = columns
  end

  def to_a
    serializer = WorkCartSerializer.new(columns: @columns)
    data = []
    data << serializer.title_row
    @scope.includes(:leaf_representative, :contained_by).find_each do |work|
      data << serializer.row(work)
    end
    data
  end
end
