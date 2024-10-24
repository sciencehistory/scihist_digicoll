class PasswordsController < Devise::PasswordsController
  def new
    return redirect_if_azure if ScihistDigicoll::Env.lookup(:log_in_using_azure)
    super
  end

  def edit
    return redirect_if_azure if ScihistDigicoll::Env.lookup(:log_in_using_azure)
    super
  end

  def update
    return redirect_if_azure if ScihistDigicoll::Env.lookup(:log_in_using_azure)
    super
  end

  def create
    return redirect_if_azure if ScihistDigicoll::Env.lookup(:log_in_using_azure)
    super
  end

  private
  def redirect_if_azure
    if ScihistDigicoll::Env.lookup(:log_in_using_azure)
      flash[:alert] = "Passwords are managed in Microsoft Azure now."
      redirect_back(fallback_location: root_path)
    end
  end
end