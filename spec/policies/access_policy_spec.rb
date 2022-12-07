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

    context "is the right kind of user" do 
      it "is in fact an admin user" do
        expect(user.admin_user?).to be true
      end
      it "is not an editor user" do
        expect(user.editor_user?).to be false
      end
    end

    context "rules explicitly stated in the admin role are followed" do
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
    end

    context "checks rules defined in the editor role, which implicitly apply" do
      it "can delete a QueueItemComment" do
        expect(policy.can?(:destroy, comment_you_can_delete)).to be true
      end
      it "can't delete a QueueItemComment by someone else" do
        expect(policy.can?(:destroy, coment_you_can_t_delete)).to be false
      end
    end

    context "rules defined on Kithe::Model in the staff role should apply to its subclasses, and be applied to the admin role as well" do
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


  end

  describe 'staff' do
    let(:user) { FactoryBot.create(:user, email: "staff@b.c") }
    let(:policy) { AccessPolicy.new(user) }

    context "is the right kind of user" do 
      it "user is not an admin user" do
        expect(user.admin_user?).to be false
      end
      it "user is an editor user" do
        expect(user.editor_user?).to be true
      end
    end

    context "does not allow unpermitted operations on collections, works and assets" do 
      it "cannot create a new collection" do
        expect(policy.can?(:create, Collection)).to be false
      end
      it "cannot destroy a particular collection" do
        expect(policy.can?(:destroy, collection)).to be false
      end
      it "cannot create a new work" do
        expect(policy.can?(:create, Work)).to be false
      end
      it "cannot create a new asset" do
        expect(policy.can?(:create, Asset)).to be false
      end
    end

    context "operations on Kithe::Model that are explicitly allowed" do 
      it "can update a Kithe::Model" do
        expect(policy.can?(:read, Kithe::Model)).to be true
      end
      it "can read a Kithe::Model" do
        expect(policy.can?(:read, Kithe::Model)).to be true
      end
      it "can, however, read a particular unpublished asset" do
        expect(policy.can?(:read, unpublished_asset)).to be true
      end
      it "cannot manage users" do
        expect(policy.can?(:manage, User)).to be false
      end
      it "can access staff functions" do
        expect(policy.can?(:access_staff_functions)).to be true
      end
    end

    context "rules about Kithe::Model should apply to its subclasses" do
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
  end

  describe 'non-logged-in user' do
    let(:policy) { AccessPolicy.new(nil) }
    context "smoke tests" do 
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

    context "rules about Kithe::Model should apply to its subclasses" do
      it "cannot read any Kithe::Model" do
        skip "`published` isn't defined on Kithe::Model so we can't use this right now"
        expect(policy.can?(:read, Kithe::Model)).to be false
      end
    end
  end

end
