require 'rails_helper'

describe ViewModel do

  class self::WidgetFormatter < ViewModel
    valid_model_type_names 'String', 'NilClass'
    def format_the_widget
      return "formatted widget"
    end
  end

  it "passes basic smoke test" do
    result = self.class::WidgetFormatter.
      new('unformatted widget').
      format_the_widget
    expect(result).to eq "formatted widget"
  end

  it "checks the type of constructor args belong to the list provided" do
    expect {
      self.class::WidgetFormatter.new.format_the_widget
    }.to raise_error ArgumentError
  end

end