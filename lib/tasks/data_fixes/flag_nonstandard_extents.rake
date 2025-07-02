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

    # bundle exec rake scihist:data_fixes:flag_nonstandard_extents
    desc "Flag nonstandard extents"
    task :flag_nonstandard_extents => :environment do

      scope = Work.where("json_attributes -> 'department' ?| array[:depts  ]", depts:   ['Museum'] ).
        where("json_attributes -> 'extent' IS NOT NULL AND json_attributes -> 'extent' != '[]'")



      weird_items = []

      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |work|
          work.extent.each do |ext|
            tmp = ext

            # extents to ignore:
            next if ext.include? 'page'
            next if ext.include? 'item'
            next if ext.include? 'Item'
            next if ext.include? 'oz.'

            standard_extent_regex = /\d*\.*\d*\s+(in\.?|cm\.?|mm\.?)/

            # remove standard extents like "12.45 in."
            tmp = ext.gsub(standard_extent_regex) {|s|  ""}

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
              converted = ext.gsub(standard_extent_regex) { |s| InchesToCentimetersConverter.new(s).centimeters }
              puts work.friendlier_id
              pp ext
              pp converted
              puts
            else
              weird_items << "#{work.friendlier_id.rjust(10)}  #{ext.rjust(50)}  #{tmp.rjust(30)}"
            end
          end
        end
      end

      puts "Nonstandard extents:"
      puts
      puts "#{'ID'.rjust(10)}  #{'Extent'.rjust(50)}  #{'Flagged'.rjust(30)}"
      puts weird_items
    end
  end
end
