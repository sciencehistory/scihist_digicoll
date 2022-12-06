require 'rails_helper'

describe "policies" do

  let!(:admin_user)  { FactoryBot.create(:admin_user,  email: "admin@b.c") }
  let!(:staff_user) { FactoryBot.create(:user, email: "staff@b.c") }

  let!(:admin_policy) { AccessPolicy.new(admin_user) }
  let!(:staff_policy) { AccessPolicy.new(staff_user) }
  let!(:public_policy) { AccessPolicy.new(nil) }

  let!(:published_asset) { create(:asset_with_faked_file, published: true) }
  let!(:unpublished_asset) { create(:asset_with_faked_file, published: false) }
  let!(:collection) { create(:collection) }

  describe 'admin' do
    let(:policy) { admin_policy }
    let(:user) { admin_user }

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
    it "can destroy any Collection" do
      expect(policy.can?(:destroy, Collection)).to be true
    end
    it "can manage users" do
      expect(policy.can?(:admin, User)).to be true
    end
    it "can access staff functions" do
      expect(policy.can?(:access_staff_functions)).to be true
    end

    it "can create a new collection" do
      skip "This isn't explicitly stated in the policy description for :admin"
      expect(policy.can?(:create, Collection)).to be true
    end
    it "can create a new work" do
      skip "This isn't explicitly stated in the policy description for :admin"
      expect(policy.can?(:create, Work)).to be true
    end
    it "can create a new asset" do
      skip "This isn't explicitly stated in the policy description for :admin"
      expect(policy.can?(:create, Asset)).to be true
    end
    it "can read a Kithe::Model" do
      skip "Kithe::Model isn't explicitly stated in the policy description for :admin"
      expect(policy.can?(:read, Kithe::Model)).to be false
    end
    it "can update a Kithe::Model" do
      skip "Kithe::Model isn't explicitly stated in the policy description for :admin"
      expect(policy.can?(:update, Kithe::Model)).to be false
    end

  end

  describe 'staff' do
    let(:policy) { staff_policy }
    let(:user) { staff_user }

    it "user is not an admin user" do
      expect(user.admin_user?).to be false
    end
    it "user is an editor user" do
      expect(user.editor_user?).to be true
    end
    it "cannot create a new collection" do
      expect(policy.can?(:create, Collection)).to be false
    end
    it "cannot create a new work" do
      expect(policy.can?(:create, Work)).to be false
    end
    it "cannot create a new asset" do
      expect(policy.can?(:create, Asset)).to be false
    end
    it "can update a Kithe::Model" do
      expect(policy.can?(:read, Kithe::Model)).to be true
    end
    it "can read a Kithe::Model" do
      expect(policy.can?(:read, Kithe::Model)).to be true
    end
    it "can, however, read a particular unpublished asset" do
      expect(policy.can?(:read, unpublished_asset)).to be true
    end
    it "cannot destroy a collection" do
      expect(policy.can?(:destroy, collection)).to be false
    end
    it "cannot manage users" do
      expect(policy.can?(:manage, User)).to be false
    end
    it "can access staff functions" do
      expect(policy.can?(:access_staff_functions)).to be true
    end
    it "can read an Asset" do
      skip "Policy mentions Kithe::Model, not its subclasses."
      expect(policy.can?(:read, Asset)).to be true
    end
    it "can read a Work" do
      skip "Policy mentions Kithe::Model, not its subclasses."
      expect(policy.can?(:read, Work)).to be true
    end
    it "can read a Collection" do
      skip "Policy mentions Kithe::Model, not its subclasses."
      expect(policy.can?(:read, Collection)).to be true
    end
  end

  describe 'public' do
    let(:policy) { public_policy }
    let(:user) { staff_user }
    it "cannot read an unpublished asset" do
      expect(policy.can?(:read, unpublished_asset)).to be false
    end
    it "can read a published asset" do
      expect(policy.can?(:read, published_asset)).to be true
    end
    it "cannot read any Kithe::Model" do
      skip "`published` isn't defined on Kithe::Model so we can't use this right now"
      expect(policy.can?(:read, Kithe::Model)).to be false
    end
    it "cannot access staff functions" do
      expect(policy.can?(:access_staff_functions)).to be false
    end
  end

end
