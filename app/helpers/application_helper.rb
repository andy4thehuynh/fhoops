module ApplicationHelper
  # The succinct, human timestamp used across the app:
  #   today       -> "2:34 PM"
  #   yesterday   -> "Yesterday"
  #   this week   -> "Tue"
  #   this year   -> "Mar 3"
  #   older       -> "Mar 3, 2023"
  def succinct_timestamp(time)
    return "" if time.blank?

    date, today = time.to_date, Time.zone.today

    if date == today
      time.strftime("%-l:%M %p")
    elsif date == today.yesterday
      "Yesterday"
    elsif date > today - 7
      time.strftime("%a")
    elsif date.year == today.year
      time.strftime("%b %-d")
    else
      time.strftime("%b %-d, %Y")
    end
  end
end
