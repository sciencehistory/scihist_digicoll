class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  # commented out :registerable -jrochkind
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable
end
