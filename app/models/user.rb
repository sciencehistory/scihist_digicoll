class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  #
  # jrochkind did:
  # * comment out registerable, we don't allow registrations
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable


  # Only used by devise validatable, we want to allow user accounts
  # to be saved with nil password, means they won't be able to log in
  # with any password.
  def password_required?
    false
  end
end
