class InchesToCentimetersConverter
  
  def initialize(str)
    @str = str
  end

  def centimeters
    return @str unless @str.include? 'in'
    @str.gsub(/^[\d\.]+/) { |num| (num.to_f * 2.54).round(2) }.gsub(/in.?/, 'cm')
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


      weird_items = []
      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |work|
          work.extent.each_with_index do |extent, index|

            # extents to ignore:
            next if extent.include? 'page'
            next if extent.include? 'item'
            next if extent.include? 'Item'
            next if extent.include? 'oz.'

            standard_extent_regex = /\d*\.*\d*\s+(in\.?|cm\.?|mm\.?)/

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

            # ignore if all we have left are spaces:
            if tmp.gsub(/ /, '') == ''
              converted_extent = extent.gsub(standard_extent_regex) do |s|
                InchesToCentimetersConverter.new(s).centimeters
              end


              puts work.friendlier_id
              puts work.extent[index]
              puts converted_extent
              puts
              
              work.extent[index] = converted_extent unless dry_run
            else
              weird_items << "#{work.friendlier_id.rjust(10)}  #{extent.rjust(50)}  #{tmp.rjust(30)}"
            end
          end
          work.save! unless dry_run
        end
      end

      if weird_items.count > 0
        puts "Nonstandard extents:"
        puts
        puts "#{'ID'.rjust(10)}  #{'Extent'.rjust(50)}  #{'Flagged'.rjust(30)}"
        puts weird_items
      end

    end
  end
end
