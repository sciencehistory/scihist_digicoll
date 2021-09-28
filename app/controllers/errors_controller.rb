# Custom error pages for Rails ala https://www.marcelofossrj.com/recipe/2019/04/14/custom-errors.html
#
# We don't use the application layout though, templates files have full <html>, for simpler
# pages with less that can go wrong. And just because that's how we were doing it before, and
# it worked.

class ErrorsController < ApplicationController
   def not_found
     respond_to do |format|
       format.html { render status: 404, layout: false }
       format.json { render json: { error: "Resource not found" }, status: 404 }
     end
   end

   def unacceptable
     respond_to do |format|
       format.html { render status: 422, layout: false }
       format.json { render json: { error: "Params unacceptable" }, status: 422 }
     end
   end

   def internal_error
     respond_to do |format|
       format.html { render status: 500, layout: false }
       format.json { render json: { error: "Internal server error" }, status: 500 }
     end
   end
end
