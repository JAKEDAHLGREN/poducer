# db/seeds.rb

users = [
  [ "user@user.com",      :user ],
  [ "one@user.com",       :user ],
  [ "two@user.com",       :user ],
  [ "producer@producer.com", :producer ],
  [ "one@producer.com",   :producer ],
  [ "two@producer.com",   :producer ],
  [ "admin@admin.com",    :admin ],
  [ "one@admin.com",      :admin ],
  [ "two@admin.com",      :admin ]
]

users.each do |email, role|
  User.find_or_create_by!(email: email) do |u|
    u.password = "12345"  # has_secure_password writes password_digest
    u.role     = role
  end
end

Podcast.find_or_create_by!(user: User.first,  name: "Podcast 1")  { |p| p.description = "Description 1"; p.primary_category = "Category 1" }
Podcast.find_or_create_by!(user: User.second, name: "Podcast 2")  { |p| p.description = "Description 2"; p.primary_category = "Category 2" }
Podcast.find_or_create_by!(user: User.third,  name: "Podcast 3")  { |p| p.description = "Description 3"; p.primary_category = "Category 3" }

Episode.find_or_create_by!(podcast: Podcast.first,  number: 1) { |e| e.name = "Episode 1"; e.description = "Description 1"; e.release_date = Date.today }
Episode.find_or_create_by!(podcast: Podcast.second, number: 2) { |e| e.name = "Episode 2"; e.description = "Description 2"; e.release_date = Date.today }
Episode.find_or_create_by!(podcast: Podcast.third,  number: 3) { |e| e.name = "Episode 3"; e.description = "Description 3"; e.release_date = Date.today }
