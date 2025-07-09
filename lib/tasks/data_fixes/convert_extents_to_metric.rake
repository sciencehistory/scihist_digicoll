class InchesToCentimetersConverter
  
  # Takes a form
  def initialize(str)
    @str = str
  end

  def centimeters
    # anything that doesn't have 'in' - do not alter.
    return @str unless @str.match /\d*\.*\d*\s+in/

    @str = @str.gsub(/^[\d\.]+/) do |num|
      (num.to_f * 2.54).round(1) 
    end

    @str = @str.gsub(/in.?/, 'cm')

    @str
  end

end


namespace :scihist do
  namespace :data_fixes do

    # bundle exec rake scihist:data_fixes:convert_extents_to_metric
    desc "Convert extents to metric"
    task :convert_extents_to_metric => :environment do
      dry_run = (ENV['DRY_RUN'] == "true")
      if dry_run
        puts "DRY RUN\n\n"
      else
        puts "CHANGING DATA\n\n"
      end

      scope = Work.where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Museum'] ).
        where("json_attributes -> 'extent' IS NOT NULL AND json_attributes -> 'extent' != '[]'")


      nonstandard_items = []
      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |work|
          work.extent.each_with_index do |extent, index|

            # extents to ignore:
            next if extent.include? 'page'
            next if extent.include? 'item'
            next if extent.include? 'Item'
            next if extent.include? 'oz.'

            standard_extent_regex = /\d*\.*\d*\s+(in\.?|cm\.?|mm\.?)/

            # validate the extent and flag it if it's ill-formed in some way:
            tmp = extent
            # remove standard extents like "12.45 in."
            tmp = tmp.gsub(standard_extent_regex) {|s|  ""}
            # remove label at end (in parentheses)
            tmp = tmp.gsub( /\([\w -]*\)$/ , '')
            # remove label at beginning (separated by semicolon)
            tmp = tmp.gsub( /^[\w &]*:/ , '')
            # standardize D and C
            tmp = tmp.gsub(/Diameter|Diam\.?/, 'D')
            tmp = tmp.gsub(/Circumference|Circum\.?|Circ\.?/, 'C')
            # remove dimension labels
            tmp = tmp.gsub(/ H| W| D| C| L/, '')
            # remove x's
            tmp = tmp.gsub(/ x/, '')

            #if the extent is well-formed, then all we should have left is spaces.
            if tmp.gsub(/ /, '') == ''

              #calculate converted extent and modify the extent.
              converted_extent = extent.gsub(standard_extent_regex) do |s|
                InchesToCentimetersConverter.new(s).centimeters
              end

              unless work.extent[index] == converted_extent
                puts "#{work.friendlier_id}\t#{index}\t#{work.extent[index]}\t#{converted_extent}"                 
                work.extent[index] = converted_extent unless dry_run
              end
              
            else
              nonstandard_items << "#{work.friendlier_id.rjust(10)}  #{extent.rjust(50)}  #{tmp.rjust(30)}"
            end
          end
          work.save! unless dry_run
        end
      end

      if nonstandard_items.count > 0
        puts "Nonstandard extents:"
        puts
        puts "#{'ID'.rjust(10)}  #{'Extent'.rjust(50)}  #{'Flagged'.rjust(30)}"
        puts nonstandard_items
      end

    end
  end
end
