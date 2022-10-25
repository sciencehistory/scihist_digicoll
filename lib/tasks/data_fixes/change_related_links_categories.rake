namespace :scihist do
  namespace :data_fixes do
    desc """
      Change distillations_* related link cateogries to institute_*
    """
    task :change_distillations_categories => :environment do

      delta = {
        "distillations_article" => "institute_article",
        "distillations_podcast" => "institute_podcast",
        "distillations_video" => "institute_video"
      }

      Kithe::Indexable.index_with(batching: true) do
        # could be a Work or a Collection
        Kithe::Model.where("json_attributes -> 'related_link' is not NULL").find_each do |model|
          if model.related_link.collect(&:category).intersection(delta.keys).present?
            model.related_link.each do |rl|
              rl.category = delta.fetch(rl.category, rl.category)
            end
            model.save!
          end
        end
      end
    end
  end
end
