namespace :scihist do
  namespace :data_fixes do
    desc """
      bundle exec rake scihist:data_fixes:publish_child_works
      See https://github.com/sciencehistory/scihist_digicoll/issues/2477
    """

    task :publish_child_works => :environment do
      Kithe::Indexable.index_with(batching: true) do        
        work_ids=['e172xgb', 'ulbrb9w', 'xoe9glc', 'vx7n5ou']

        work_ids.each do |parent_id|
          parent = Work.find_by_friendlier_id(parent_id)

          # PROMOTE CHILD WORKS:
          parent.members.each do |member|
            member.update( {parent_id: nil } )
            puts "Promoted child work #{member.friendlier_id}"
          end
          
          # UNPUBLISH:
          parent.update({published: false})
          parent.admin_note << 'Unpublished per: https://github.com/sciencehistory/scihist_digicoll/issues/2477'
          puts "Unpublished parent work #{parent.friendlier_id}"
          parent.save!
        end

      end
    end
  end
end
