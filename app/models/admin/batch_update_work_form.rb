require 'delegate'

module Admin

  #
  # This is a sort of "wrapper" (delegator/proxy, "form object") around a work, meant for use with the
  # Batch Update form -- we wrap it so we can _remove_ certain validations, so we can validate
  # batch edit entry but not have it fail on things like "needs an external_id" -- batch edit
  # instructions don't need an external id!
  #
  # In fact, we just remove all "presence" validations. But we still want validations like "Creator
  # can't have a blank role" -- and we want them to be displayed nicely on the batch edit form.
  #
  # Additioally, we want simple_form's introspection into validations to _also_ not find the
  # "presence" ones, so it won't mark them as "required".
  #
  # So a BatchUpdatetWorkValidator should end up looking pretty much just like a Work, through
  # the magic of delegation, but without those validations.
  #
  # Getting this to work is pretty hacky, and required some reverse engineering of Rails and simple_form,
  # indeed it's not great. But this seems to be the simplest way
  # to be able to re-use our forms and validation and error-displaying code from Work edit.
  #
  # We also have the logic for actually doing the update in here. Normally it will look like this:
  #
  #     @work = BatchUpdateWorkForm.new(work_params)
  #     result = @work.update_works(current_user.works_in_cart.find_each)
  #     # if result is false, then it failed, and there are @work.errors to look at.
  #
  # A BatchUpdateWorkForm instance should be more or less interchangeable with a work,
  # especially for passing to simple_form to create a form, and display errors, etc.
  class BatchUpdateWorkForm < SimpleDelegator
    alias_method :work, :__getobj__

    NON_INCLUDED_VALIDATORS = proc { |validator| validator.kind_of?(ActiveRecord::Validations::PresenceValidator) }

    # We get the Rails form params sent by our form, which are full of weird stuff, but we know
    # it will work with assign_attributes. So we create a "dummy" work (marked read-only), that
    # we can use to look at what batch edit instructions were given, and validate them.
    def initialize(form_params)
      work = Work.new.tap { |w| w.readonly! }.tap { |w| w.assign_attributes(form_params) }

      super(work)
    end

    # Al Work validators EXCEPT "presence" ones are our validators
    def self.validators
      @validators ||= Work.validators.reject(&NON_INCLUDED_VALIDATORS)
    end

    # This method is used by simple form reflection to mark fields "required", so again
    # we need it to be all Work validators EXCEPT presence ones, so simple_form won't
    # mark any fields required.
    def self.validators_on(*attributes)
      super.reject(&NON_INCLUDED_VALIDATORS)
    end

    # We need to make sure this reflection-related _class_ methods is delegated too,
    # for simple_form and other reflection.
    def self.method_defined?(*args)
      super || Work.method_defined?(*args)
    end

    # We need to make sure this reflection-related _class_ methods is delegated too,
    # for simple_form and other reflection.
    def self.respond_to?(*args)
      super || Work.respond_to?(*args)
    end

    # Make sure all class methods are also delegated to Work, cause simple_form,
    # attr_json, etc., try it on the instance we pass to the form.
    def self.method_missing(message, *args, &block)
      Work.send(message, *args, &block)
    end


    # Simply if all of _our_ validations pass (Ie, Work validations without ones we excluded)
    def valid?
      work.errors.clear

      self.class.validators.each do |validator|
        validator.validate(work)
      end

      work.errors.empty?
    end

    # These errors are used by simple_form to echo errors to user on form, including
    # field-specific errors. Calling the validators on the work in #valid? above will
    # also fill out errors on the Work for any validators we called that failed.
    def errors
      work.errors
    end

    # Pull just non-blank ones out of the Work. We assume we only want to update
    # things that are in attr_json, so we can use that as a list of what to check.
    #
    # @returns [Hash] key attribute name, value is the entered values to set or add
    # to every item in our update. Will be an array for multi-valued array fields,
    # otherwise a single hash or primitive.
    def update_attributes
      Work.attr_json_registry.definitions.reduce({}) do |hash, attr_defn|
        value = work.send(attr_defn.name)
        if value.present?
          hash[attr_defn.name] = value
        end
        hash
      end
    end

    # Pass in an activerecord relation (usually `current_user.works_in_cart.find_each`),
    # we will update them all with the edits specified by this Batch Update operation,
    # that is the attributes passed in initializer.
    #
    # All values specified as update_attributes are _added on_ to multi-valued fields, or
    # else replace single-valued fields.
    #
    # Returns true or false; if returning false on failure, there should be ActiveModel::Errors
    # in #errors, suitable for display by eg the batch edit form.
    def update_works(relation)
      unless self.valid?
        # don't even try, the batch edit instructions were invalid.
        # Our #errors will be filled out for redisplay.
        return false
      end

      # Do it in a transaction, don't update any unless we can update them all.
      Work.transaction do
        relation.each do |each_work|
          update_attributes.each do |k, v|
            if v.kind_of?(Array)
              each_work.send("#{k}=", each_work.send(k) + v)
            else
              each_work.send("#{k}=", v)
            end

            unless each_work.valid?
              # This shouldn't normally happen because we already validated the batch entry input on it's own.
              # But maybe one of the records started out invalid? Or unexpected things happen.
              # Record it as a somewhat mysterious error on our dummy work so the form will show it, and abort our mission
              # returning false.

              work.errors.add(:base,"Some works in the cart couldn't be saved, they may have pre-existing problems. The batch update was not done.")
              work.errors.add(:base, "#{each_work.title} (#{each_work.friendlier_id}): #{each_work.errors.full_messages.join(', ')}")
              return false
            end

            each_work.save!
          end
        end
      end
      return true
    end

    # make simple_form use this, not the wrapped model, so it does validation
    # reflection on our altered ones.
    def to_model
      self
    end
  end
end
