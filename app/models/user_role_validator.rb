class UserRoleValidator < ActiveModel::Validator
  def validate(record)
    if record.admin?
      unless record.role.nil?
        record.errors.add :role, "This user is an administrator, so they can't have another role."
      end
    else
      if record.role.nil?
        record.errors.add :role, "This user is not an administrator, so they need to have some other role."
      end
    end
  end
end