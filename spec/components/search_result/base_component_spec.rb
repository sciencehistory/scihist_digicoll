require 'rails_helper'

describe SearchResult::BaseComponent do
  describe "#search_highlights" do
    let(:work) { create(:work, :with_complete_metadata) }
    let(:child_counter) { ChildCountDisplayFetcher.new([work.friendlier_id]) }

    let(:presenter) do
      SearchResult::BaseComponent.new(work, child_counter: child_counter, solr_document: mocked_solr_document)
    end

    describe "multiple snippets" do
      let(:mocked_solr_document) do
        # Solr is html-escaping ALL the punctuation in html-encoded highlighting response, I dunno, but okay.
        SolrDocument.new(
          { 'id' => work.friendlier_id },
          { 'highlighting' =>
            { work.friendlier_id =>
              {
                "searchable_fulltext_en"=>
                  ["operated&#32;the&#32;<em>Potlatch</em>&#10;<em>Lumber</em>&#32;Company&#46;&#32;", "the&#32;<em>Potlatch</em>&#32;<em>Lumber</em>&#32;Company&#44;&#32;who&#10;was&#32;a&#32;laird&#32;in&#32;"]
              }
            }
          }
        )
      end

      it "is marked html_safe" do
        expect(presenter.search_highlights).to be_html_safe
      end

      it "formats" do
        # Solr is html-escaping ALL the punctuation, I dunno, but okay.
        expect(presenter.search_highlights).to eq(
          "…operated&#32;the&#32;<em>Potlatch</em>&#10;<em>Lumber</em>&#32;Company&#46;&#32; …the&#32;<em>Potlatch</em>&#32;<em>Lumber</em>&#32;Company&#44;&#32;who&#10;was&#32;a&#32;laird&#32;in&#32;…"
        )
      end
    end

    describe "one snippet" do
      let(:mocked_solr_document) do
        # Solr is html-escaping ALL the punctuation in html-encoded highlighting response, I dunno, but okay.
        SolrDocument.new(
          { 'id' => work.friendlier_id },
          { 'highlighting' =>
            { work.friendlier_id =>
              {
                "searchable_fulltext_en"=>
                  ["operated&#32;the&#32;<em>Potlatch</em>&#10;<em>Lumber</em>&#32;Company&#46;&#32;", "the&#32;<em>Potlatch</em>&#32;<em>Lumber</em>&#32;Company&#44;&#32;who&#10;was&#32;a&#32;laird&#32;in&#32;"]
              }
            }
          }
        )
      end

      it "formats" do
        expect(presenter.search_highlights).to eq(
          "…operated&#32;the&#32;<em>Potlatch</em>&#10;<em>Lumber</em>&#32;Company&#46;&#32; …the&#32;<em>Potlatch</em>&#32;<em>Lumber</em>&#32;Company&#44;&#32;who&#10;was&#32;a&#32;laird&#32;in&#32;…"
        )
      end
    end

    describe "no snippets" do
      let(:mocked_solr_document) do
        SolrDocument.new(
          { 'id' => work.friendlier_id },
          { 'highlighting' =>
            { work.friendlier_id =>
              {
                "searchable_fulltext_en" => []
              }
            }
          }
        )
      end

      it "returns empty string" do
        expect(presenter.search_highlights).to eq("")
      end
    end

    describe "response missing highlighting key entirely" do
     let(:mocked_solr_document) do
        SolrDocument.new(
          { 'id' => work.friendlier_id },
          {}
        )
      end

      it "returns empty string" do
        expect(presenter.search_highlights).to eq("")
      end
    end

  end
end
