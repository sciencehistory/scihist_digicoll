# Admin users have a 'cart' of items. Which is just many-to-many
# relationship between users and works, the 'cart' has no existence
# other than the collection of works related to the user through
# a many-to-many relationship.
class CartItem < ApplicationRecord
  belongs_to :user
  belongs_to :work
end
