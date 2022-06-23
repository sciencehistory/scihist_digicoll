class FixTranslatorTypo < ActiveRecord::Migration[6.1]
  # additional credit name from "Julie Huggony" to 'Julie Hugonny'
  def change
    Work.jsonb_contains("additional_credit.name": "Julie Huggony").each do |work|
      work.additional_credit.find_all { |ac| ac.name == "Julie Huggony"}.each do |ac|
        ac.name = 'Julie Hugonny'
      end
      work.save!
    end
  end
end
