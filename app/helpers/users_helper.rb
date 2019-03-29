module UsersHelper
  def user_account_state(user)
    if !user.active?
      content_tag :span, 'inactive', class: 'badge badge-danger'
    elsif user.access_locked?
      content_tag :span, 'locked', class: 'badge badge-danger'
    elsif ENV['REQUIRE_CONFIRMED_EMAIL'] == 'true' && !user.confirmed?
      content_tag :span, 'unconfirmed', class: 'badge badge-warning'
    else
      content_tag :span, 'active', class: 'badge badge-success'
    end
  end
end
