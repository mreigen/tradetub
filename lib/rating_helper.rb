module RatingHelper
  def get_average_ratings_from_user(user)
    return if user.blank?
    avg_rating = 0
    offers_by_user = user.offers.accepted
    offers_by_user.each do |offer|
    	avg_rating += offer.rating.score unless offer.rating.nil?
    end
    avg_rating = avg_rating / offers_by_user.count if offers_by_user.count != 0
    0
  end
end