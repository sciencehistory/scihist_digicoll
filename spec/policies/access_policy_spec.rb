require 'rails_helper'

describe "access policies:" do
  let!(:published_asset) { create(:asset_with_faked_file, published: true) }
  let!(:unpublished_asset) { create(:asset_with_faked_file, published: false) }
  let!(:collection) { create(:collection) }

  describe 'admin' do
    let(:user)  { FactoryBot.create(:admin_user,  email: "admin@b.c") }
    let(:policy) { AccessPolicy.new(user) }
    let(:comment_you_can_delete) { Admin::QueueItemComment.new(user: user)}
    let(:coment_you_can_t_delete) { Admin::QueueItemComment.new(user: nil)}

    it "is in fact an admin user" do
      expect(user.admin_user?).to be true
    end
    it "is not an editor user" do
      expect(user.editor_user?).to be false
    end
    it "can read an unpublished asset" do
      expect(policy.can?(:read, unpublished_asset)).to be true
    end
    it "can destroy a particular collection" do
      expect(policy.can?(:destroy, collection)).to be true
    end
    it "can destroy any Kithe::Model" do
      expect(policy.can?(:destroy, Kithe::Model)).to be true
    end
    it "can manage users" do
      expect(policy.can?(:admin, User)).to be true
    end
    it "can access staff functions" do
      expect(policy.can?(:access_staff_functions)).to be true
    end
    it "can delete a QueueItemComment" do
      expect(policy.can?(:destroy, comment_you_can_delete)).to be true
    end
    it "can't delete a QueueItemComment by someone else" do
      expect(policy.can?(:destroy, coment_you_can_t_delete)).to be false
    end
    it "can read a Kithe::Model" do
      expect(policy.can?(:read, Kithe::Model)).to be true
    end
    it "can update a Kithe::Model" do
      expect(policy.can?(:update, Kithe::Model)).to be true
    end
  end

  describe 'editor / staff' do
    let(:user) { FactoryBot.create(:user, email: "staff@b.c") }
    let(:policy) { AccessPolicy.new(user) }

    it "user is not an admin user" do
      expect(user.admin_user?).to be false
    end
    it "user is an editor user" do
      expect(user.editor_user?).to be true
    end
    it "cannot destroy a particular collection" do
      expect(policy.can?(:destroy, collection)).to be false
    end
    it "can update a Kithe::Model" do
      expect(policy.can?(:update, Kithe::Model)).to be true
    end
    it "can read a Kithe::Model" do
      expect(policy.can?(:read, Kithe::Model)).to be true
    end
    it "cannot destroy a Kithe::Model" do
      expect(policy.can?(:destroy, Kithe::Model)).to be false
    end
    it "can read a particular unpublished asset" do
      expect(policy.can?(:read, unpublished_asset)).to be true
    end
    it "cannot manage users" do
      expect(policy.can?(:manage, User)).to be false
    end
    it "can access staff functions" do
      expect(policy.can?(:access_staff_functions)).to be true
    end
  end

  describe 'non-logged-in user' do
    let(:policy) { AccessPolicy.new(nil) }
    it "can read a published asset" do
      expect(policy.can?(:read, published_asset)).to be true
    end
    it "cannot read an unpublished asset" do
      expect(policy.can?(:read, unpublished_asset)).to be false
    end
    it "cannot access staff functions" do
      expect(policy.can?(:access_staff_functions)).to be false
    end
  end

end
