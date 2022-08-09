module ScihistDigicoll
  module TaskHelpers
    # This is meant to be called by the rake task scihist:data_fixes:update_related_urls
    # which instantiates this class *once*, then calls process_work(work) on each work in the collection.
    # process_work just updates the related_urls of a work according to @metadata_map.
    class RelatedUrlUpdater
      attr_accessor :metadata_map, :keys_to_check_for, :changes, :errors
      
      def initialize
        @changes = []
        @errors = []
        @keys_to_check_for = metadata_map.keys
        raise ArgumentError, "Can't have nil values for metadata_map" if metadata_map.values.any?(&:nil?)
      end

      def change_if_necessary(value)
        metadata_map.fetch(value, value)
      end

      # Update the work, but only if it has something that needs to be changed.
      def process_work(work)
        update_related_url(work) unless (work.related_url & @keys_to_check_for).empty?
      end

      # Update all related URLs according to metadata_map.
      def update_related_url(work)
        updated_url = work.related_url.map { |s| change_if_necessary(s) }
        if work.update({related_url: updated_url})
          @changes <<  [ work.friendlier_id, work.title, updated_url ]
        else
          @errors << [ work.friendlier_id, work.title, work.updated_url, 'could not change url']
        end
      end

      def metadata_map
        @metadata_map ||= begin
          host = 'https://archives.sciencehistory.org'
          paths = {
            "/2012-002.html" => "/repositories/3/resources/1",
            "/2022-508.html" => "/repositories/3/resources/170",
            "/2014-016.html" => "/repositories/3/resources/2",
            "/2013-037.html" => "/repositories/3/resources/4",
            "/1997-01.html"  => "/repositories/3/resources/5",
            "/2014-023.html" => "/repositories/3/resources/7",
            "/2015-003.html" => "/repositories/3/resources/8",
            "/2015-028.html" => "/repositories/3/resources/9",
            "/2013-032.html" => "/repositories/3/resources/10",
            "/2014-014.html" => "/repositories/3/resources/11",
            "/2014-009.html" => "/repositories/3/resources/12",
            "/2005-017.002.html" => "/repositories/3/resources/14",
            "/2010-028.html" => "/repositories/3/resources/15",
            "/2003-902.html" => "/repositories/3/resources/16",
            "/2004-012.002.html" => "/repositories/3/resources/17",
            "/2010-024.002.html" => "/repositories/3/resources/18",
            "/2004-505.html" => "/repositories/3/resources/19",
            "/A93-02.001.html" => "/repositories/3/resources/20",
            "/2004-525.html" => "/repositories/3/resources/21",
            "/2008-033.002.html" => "/repositories/3/resources/22",
            "/2013-045.html" => "/repositories/3/resources/23",
            "/2001-004.008.html" => "/repositories/3/resources/24",
            "/2006-502.002.html" => "/repositories/3/resources/25",
            "/2013-038.html" => "/repositories/3/resources/26",
            "/2004-005.html" => "/repositories/3/resources/27",
            "/2003-600.002.html" => "/repositories/3/resources/28",
            "/1991-002.002.html" => "/repositories/3/resources/29",
            "/2004-543.002.html" => "/repositories/3/resources/30",
            "/2011-042.002.html" => "/repositories/3/resources/31",
            "/2001-003.002.html" => "/repositories/3/resources/32",
            "/2013-047.html" => "/repositories/3/resources/33",
            "/2003-035.html" => "/repositories/3/resources/34",
            "/2005-025.html" => "/repositories/3/resources/35",
            "/2005-026.002.html" => "/repositories/3/resources/36",
            "/2013-036.002.html" => "/repositories/3/resources/37",
            "/2006-501.html" => "/repositories/3/resources/38",
            "/2014-029.002.html" => "/repositories/3/resources/39",
            "/2005-505.html" => "/repositories/3/resources/40",
            "/2004-524.html" => "/repositories/3/resources/41",
            "/1996-013.html" => "/repositories/3/resources/42",
            "/2003-900.html" => "/repositories/3/resources/43",
            "/2003-020.001.html" => "/repositories/3/resources/44",
            "/GB01-36.002.html" => "/repositories/3/resources/45",
            "/2012-017.002.html" => "/repositories/3/resources/46",
            "/2004-011.002.html" => "/repositories/3/resources/47",
            "/2015-032.html" => "/repositories/3/resources/48",
            "/2000-034.002.html" => "/repositories/3/resources/49",
            "/2016-019.html" => "/repositories/3/resources/50",
            "/2015-039.html" => "/repositories/3/resources/51",
            "/2006-044.html" => "/repositories/3/resources/52",
            "/2016-021.html" => "/repositories/3/resources/53",
            "/2007-158.html" => "/repositories/3/resources/54",
            "/2017-018.html" => "/repositories/3/resources/55",
            "/2017-024.html" => "/repositories/3/resources/56",
            "/2017-023.html" => "/repositories/3/resources/57",
            "/2018-006.html" => "/repositories/3/resources/58",
            "/GB90-05.html" => "/repositories/3/resources/59",
            "/GB00-16.html" => "/repositories/3/resources/60",
            "/2009-024.html" => "/repositories/3/resources/61",
            "/1998-005.html" => "/repositories/3/resources/62",
            "/1998-016.html" => "/repositories/3/resources/63",
            "/2012-020.html" => "/repositories/3/resources/64",
            "/2012-039.html" => "/repositories/3/resources/65",
            "/2009-036.html" => "/repositories/3/resources/66",
            "/2002-002.html" => "/repositories/3/resources/68",
            "/1986-002.html" => "/repositories/3/resources/69",
            "/DP01-02.html" => "/repositories/3/resources/70",
            "/2004-027.html" => "/repositories/3/resources/71",
            "/1992-009.html" => "/repositories/3/resources/72",
            "/2008-046.html" => "/repositories/3/resources/73",
            "/1989-006.html" => "/repositories/3/resources/74",
            "/1992-010.html" => "/repositories/3/resources/75",
            "/83-01.html" => "/repositories/3/resources/76",
            "/2004-011.001.html" => "/repositories/3/resources/77",
            "/2012-003.001.html" => "/repositories/3/resources/78",
            "/2007-025.html" => "/repositories/3/resources/79",
            "/2006-085.html" => "/repositories/3/resources/80",
            "/2012-021.html" => "/repositories/3/resources/81",
            "/2001-004.001.html" => "/repositories/3/resources/82",
            "/2002-015.html" => "/repositories/3/resources/83",
            "/1984-004.html" => "/repositories/3/resources/84",
            "/2004-036.001.html" => "/repositories/3/resources/85",
            "/2019-011.html" => "/repositories/3/resources/86",
            "/2014-013.html" => "/repositories/3/resources/87",
            "/2015-006.html" => "/repositories/3/resources/88",
            "/2012-023.html" => "/repositories/3/resources/91",
            "/2003-041.001.html" => "/repositories/3/resources/92",
            "/2002-012.html" => "/repositories/3/resources/93",
            "/1991-066.001.html" => "/repositories/3/resources/94",
            "/2015-502.html" => "/repositories/3/resources/95",
            "/2007-115.html" => "/repositories/3/resources/96",
            "/2009-041.html" => "/repositories/3/resources/97",
            "/1999-011.html" => "/repositories/3/resources/103",
            "/2006-121.html" => "/repositories/3/resources/104",
            "/2006-071.html" => "/repositories/3/resources/105",
            "/2005-026.001.html" => "/repositories/3/resources/106",
            "/2003-531.html" => "/repositories/3/resources/107",
            "/GB94-41.html" => "/repositories/3/resources/108",
            "/2008-025.html" => "/repositories/3/resources/109",
            "/2005-073.html" => "/repositories/3/resources/110",
            "/1992-011.001.html" => "/repositories/3/resources/111",
            "/2002-001.001.html" => "/repositories/3/resources/112",
            "/2012-042.html" => "/repositories/3/resources/113",
            "/2004-033.html" => "/repositories/3/resources/114",
            "/2007-168.html" => "/repositories/3/resources/115",
            "/1998-001.001.html" => "/repositories/3/resources/116",
            "/2008-038.001.html" => "/repositories/3/resources/117",
            "/2004-025.html" => "/repositories/3/resources/118",
            "/1993-004.html" => "/repositories/3/resources/119",
            "/2000-031.001.html" => "/repositories/3/resources/120",
            "/2009-047.001.html" => "/repositories/3/resources/121",
            "/2005-108.html" => "/repositories/3/resources/122",
            "/A93-02.002.html" => "/repositories/3/resources/123",
            "/GB96-09.html" => "/repositories/3/resources/124",
            "/2000-034.001.html" => "/repositories/3/resources/125",
            "/2003-010.001.html" => "/repositories/3/resources/126",
            "/GB14-030.html" => "/repositories/3/resources/127",
            "/2019-019.html" => "/repositories/3/resources/128",
            "/2012-019.html" => "/repositories/3/resources/129",
            "/GB19-049.html" => "/repositories/3/resources/131",
            "/GB20-008.html" => "/repositories/3/resources/132",
            "/Deposit-1995.html" => "/repositories/3/resources/133",
            "/2021-509.html" => "/repositories/3/resources/134",
            "/2020-011.html" => "/repositories/3/resources/135",
            "/2003-600.html" => "/repositories/3/resources/136",
            "/2021-035.html" => "/repositories/3/resources/137",
            "/2001-002.html" => "/repositories/3/resources/139",
            "/GB04-014.html" => "/repositories/3/resources/140",
            "/2016-531.html" => "/repositories/3/resources/141",
            "/2003-032.001.html" => "/repositories/3/resources/142",
            "/GB00-22.html" => "/repositories/3/resources/143",
            "/2011-513.html" => "/repositories/3/resources/144",
            "/2001-007.html" => "/repositories/3/resources/145",
            "/83-02.html" => "/repositories/3/resources/146",
            "/89-05.html" => "/repositories/3/resources/147",
            "/2004-012.001.html" => "/repositories/3/resources/148",
            "/2006-502.001.html" => "/repositories/3/resources/149",
            "/2022-502.html" => "/repositories/3/resources/150",
            "/89-10.html" => "/repositories/3/resources/151",
            "/91-08.html" => "/repositories/3/resources/152",
            "/2018-016.html" => "/repositories/3/resources/153",
            "/2001-003.001.html" => "/repositories/3/resources/154",
            "/2021-027.html" => "/repositories/3/resources/157",
            "/2004-037.001.html" => "/repositories/3/resources/158",
            "/2004-037.003.html" => "/repositories/3/resources/160",
            "/DP01-01.html" => "/repositories/3/resources/162",
            "/2003-015.002.html" => "/repositories/3/resources/164",
            "/00-31.html" => "/repositories/3/resources/165",
            "/2019-021.html" => "/repositories/3/resources/166",
            "/2022-503.html" => "/repositories/3/resources/167",
            "/97-03.html" => "/repositories/3/resources/168",
            "/2022-504.html" => "/repositories/3/resources/169",
          }
          result = {}
          paths.each do |key, value|
            result[host + key] = host + value
          end
          result
        end
      end
    end
  end
end