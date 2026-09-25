module ApplicationHelper
  def vat_rate_percentage(rate)
    display = rate.to_i == rate ? rate.to_i : rate
    "#{display}%"
  end
end
