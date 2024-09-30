require 'rails_helper'

describe SortedTableHeaderLinkComponent, type: :component do
  let(:params) {
  	{sort_field: 'title', sort_order: 'asc'}
  }
  let(:permitted_params) {
  	Kithe::Parameters.new(params).permit(
      :sort_field, :sort_order, :department, :page, :search_phrase
    ).tap do |hash|
      hash[:sort_field] = "title" unless hash[:sort_field].in? ['title', 'department']
      hash[:sort_order] = "asc"   unless hash[:sort_order].in? ['asc', 'desc']
    end
  }
  let(:link_maker) {
  	SortedTableHeaderLinkComponent.link_maker params: permitted_params
  }
  let(:displayer) { link_maker.link(column_title: "Title", sort_field: "title") }
  let(:rendered) { render_inline displayer }

  describe "smoke test" do
	  it "renders" do
	  	with_request_url "/admin" do
		    expect(rendered.to_s).to eq '<a href="/admin?sort_field=title&amp;sort_order=desc">Title ▲</a>'
		  end
	  end
  end

  describe "different path" do
    it "path matches" do
      with_request_url "/admin/collections" do
        expect(rendered.to_s).to eq '<a href="/admin/collections?sort_field=title&amp;sort_order=desc">Title ▲</a>'
      end
    end
  end

  describe "different column title" do
    let(:displayer) { link_maker.link(column_title: "*Title*", sort_field: "title") }
    it "renders" do
      with_request_url "/admin" do
        expect(rendered.to_s).to eq '<a href="/admin?sort_field=title&amp;sort_order=desc">*Title* ▲</a>'
      end
    end
  end

  describe "arrow matches current sort; clicking link changes direction of sort" do
    let(:params) {
      { sort_field:'title', sort_order: 'desc'}
    }
    it "renders correctly" do
      with_request_url "/admin" do
        expect(rendered.to_s).to eq '<a href="/admin?sort_field=title&amp;sort_order=asc">Title ▼</a>'
      end
    end
  end

  describe "column is not current sort" do
    let(:params) {
      { sort_field:'department', sort_order: 'desc' }
    }
    it "does not show arrow; link is for default asc" do
      with_request_url "/admin" do
        expect(rendered.to_s).to eq '<a href="/admin?sort_field=title&amp;sort_order=asc">Title</a>'
      end
    end
  end

  describe "extra params" do
    let(:params) {
      { sort_field:'department', sort_order:'desc', search_phrase: 'goat'}
    }
    it "tacked on to the link" do
      with_request_url "/admin" do
        expect(rendered.to_s).to eq  '<a href="/admin?search_phrase=goat&amp;sort_field=title&amp;sort_order=asc">Title</a>'
      end
    end
  end

  describe "arbirary sort field and order keys" do
    let(:params) {
      { sf: 'title', so: 'asc'}
    }
    let(:permitted_params) { Kithe::Parameters.new(params).permit :sf, :so }
    let(:link_maker) {
      SortedTableHeaderLinkComponent.link_maker(
        params: permitted_params,
        table_sort_field_key: :sf,
        table_sort_order_key: :so,
      )
    }
    let(:displayer) { link_maker.link(column_title: "Column_1", sort_field: "col_1") }
    it "params keys are not hardcoded" do
      with_request_url "/admin?sf=col_2&so=asc" do
        expect(rendered.to_s).to eq  '<a href="/admin?sf=col_1&amp;so=asc">Column_1</a>'
      end
    end
  end


end
