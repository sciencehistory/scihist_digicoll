require 'rails_helper'

RSpec.describe DateIndexHelper do
  let(:work) { FactoryBot.build(:work, date_of_work: date_of_work ) }
  let(:generator) { DateIndexHelper.new(work) }


  describe "#expanded_years" do
    # individual cases have to define `date_values` with `let`
    let(:index_values) { generator.expanded_years }

    describe "no dates" do
      let(:date_of_work) { [Work::DateOfWork.new] }
      it "has no index dates" do
        expect(index_values).to eq([])
      end
    end

    describe "Undated" do
      let(:date_of_work) { [ Work::DateOfWork.new(start_qualifier: "Undated") ] }
      it "has no index dates" do
        expect(index_values).to eq([])
      end
    end

    describe "decade" do
      let(:decade) { 1910 }
      let(:date_of_work) { [ Work::DateOfWork.new(start: decade.to_s, start_qualifier: "decade") ] }
      it "has whole decade" do
        expect(index_values).to eq( (decade..(decade+9)).to_a )
      end
    end

    describe "century" do
      let(:century) { 1800 }
      let(:date_of_work) { [ Work::DateOfWork.new(start: century.to_s, start_qualifier: "century") ] }
      it "has whole century" do
        expect(index_values).to eq( (century..(century+99)).to_a )
      end
    end

    describe "bare start date" do
      let(:date_of_work) { [ Work::DateOfWork.new(start: "1955-05-12") ] }
      it "has single year" do
        expect(index_values).to eq( [1955] )
      end
    end

    describe "start and end date" do
      let(:start_year) { 1954}
      let(:end_year) { 2001 }
      let(:date_of_work) { [ Work::DateOfWork.new(start: start_year.to_s, start_qualifier: "circa", finish: end_year.to_s, finish_qualifier: "circa") ] }
      it "has the range" do
        expect(index_values).to eq( (start_year..end_year).to_a )
      end
    end

    describe "multiple dates" do
      let(:date_of_work) { [ Work::DateOfWork.new(start: "1905"), Work::DateOfWork.new(start: "1910", finish: "1912") ] }
      it "has all dates" do
        expect(index_values).to match_array( (1910..1912).to_a + [1905] )
      end
    end

    describe "weird cases" do
      describe "finish before start" do
        let(:start_year) { 1954}
        let(:date_of_work) { [ Work::DateOfWork.new(start: start_year.to_s, finish: (start_year-10).to_s) ] }
        it "has only start_year" do
          expect(index_values).to eq( [start_year] )
        end
      end
      describe "finish but no start" do
        let(:date_of_work) { [ Work::DateOfWork.new(finish: "1910") ] }
        it "has no date" do
          expect(index_values).to eq( [] )
        end
      end
      describe "non-date data" do
        let(:date_of_work) { [ Work::DateOfWork.new(start: "this ain't right") ] }
        it "has no date" do
          expect(index_values).to eq( [] )
        end
      end
    end
  end

  describe "min and max" do
    let(:min_date) { generator.min_date }
    let(:max_date) { generator.max_date }

    describe "no dates" do
      let(:date_of_work) { [Work::DateOfWork.new] }

      it "has no min_date" do
        expect(min_date).to eq(nil)
      end

      it "has no max_date" do
        expect(max_date).to eq(nil)
      end
    end

    describe "Undated" do
      let(:date_of_work) { [ Work::DateOfWork.new(start_qualifier: "Undated") ] }

      it "has no min_date" do
        expect(min_date).to eq(nil)
      end

      it "has no max_date" do
        expect(max_date).to eq(nil)
      end
    end

    describe "decade" do
      let(:decade) { 1910 }
      let(:date_of_work) { [ Work::DateOfWork.new(start: decade.to_s, start_qualifier: "decade") ] }

      it "has min date at beginning of decade" do
        expect(min_date).to eq(Date.iso8601("1910-01-01"))
      end

      it "has max date at end of decade" do
        expect(max_date).to eq(Date.iso8601("1919-12-31"))
      end
    end

    describe "century" do
      let(:century) { 1800 }
      let(:date_of_work) { [ Work::DateOfWork.new(start: century.to_s, start_qualifier: "century") ] }

      it "has min date at beginning of century" do
        expect(min_date).to eq(Date.iso8601("1800-01-01"))
      end

      it "has max date at end of century" do
        expect(max_date).to eq(Date.iso8601("1899-12-31"))
      end
    end

    describe "bare start date" do
      let(:date_of_work) { [ Work::DateOfWork.new(start: "1955-05-12") ] }

      it "has min_date equal to date" do
        expect(min_date).to eq( Date.iso8601("1955-05-12") )
      end

      it "has max_date equal to date" do
        expect(max_date).to eq( Date.iso8601("1955-05-12") )
      end
    end

    describe "one date with only year/month" do
      let(:date_of_work) { [ Work::DateOfWork.new(start: "1955-04") ] }

      it "has min_date first day of month" do
        expect(min_date).to eq( Date.iso8601("1955-04-01"))
      end

      it "has max_date last day of month specific to month" do
        expect(max_date).to eq( Date.iso8601("1955-04-30") )
      end
    end

    describe "start and end year" do
      let(:start_year) { 1954}
      let(:end_year) { 2001 }
      let(:date_of_work) { [ Work::DateOfWork.new(start: start_year.to_s, start_qualifier: "circa", finish: end_year.to_s, finish_qualifier: "circa") ] }

      it "has min_date equal to beginning of start year" do
        expect(min_date).to eq(Date.iso8601("#{start_year}-01-01"))
      end

      it "has max_date equal to end of end year" do
        expect(max_date).to eq(Date.iso8601("#{end_year}-12-31"))
      end
    end

    describe "start and end just months" do
      let(:date_of_work) { [ Work::DateOfWork.new(start: "1980-10", start_qualifier: "circa", finish: "1985-09", finish_qualifier: "circa") ] }

      it "has min date equal to beginning of start month" do
        expect(min_date).to eq( Date.iso8601("1980-10-01"))
      end

      it "has max date equal to end of end month" do
        expect(max_date).to eq( Date.iso8601("1985-09-30"))
      end
    end

    describe "just month on a leap month" do
      let(:date_of_work) { [ Work::DateOfWork.new(start: "2016-02") ] }

      it "max_date has proper leap day" do
        expect(max_date).to eq Date.iso8601("2016-02-29")
      end
    end

    describe "multiple years" do
      let(:date_of_work) { [ Work::DateOfWork.new(start: "1905"), Work::DateOfWork.new(start: "1910", finish: "1912") ] }

      it "has min date equal to beginning of earliest year" do
        expect(min_date).to eq( Date.iso8601("1905-01-01") )
      end

      it "has max date equal to end of latest year" do
        expect(max_date).to eq(Date.iso8601("1912-12-31"))
      end
    end

    describe "multiple dates" do
      let(:date_of_work) { [ Work::DateOfWork.new(start: "1905-04-12"), Work::DateOfWork.new(start: "1910-03-20", finish: "1912-06-10") ] }

      it "has min date equal to earliest date" do
        expect(min_date).to eq( Date.iso8601("1905-04-12") )
      end

      it "has max date equal to latest date" do
        expect(max_date).to eq(Date.iso8601("1912-06-10"))
      end
    end

    describe "weird cases" do
      describe "non-date data" do
        let(:date_of_work) { [ Work::DateOfWork.new(start: "this ain't right") ] }

        it "has no min date" do
          expect(min_date).to be_nil
        end

        it "has no max date" do
          expect(max_date).to be_nil
        end
      end

      describe "impossible date" do
        let(:date_of_work) { [ Work::DateOfWork.new(start: "1985-06-45") ] }

        it "has no min date" do
          expect(min_date).to be_nil
        end

        it "has no max date" do
          expect(max_date).to be_nil
        end
      end
    end
  end
end
