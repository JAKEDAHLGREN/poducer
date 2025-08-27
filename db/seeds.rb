# Create Users
User.create!(email: "user@user.com", password: "password", role: :user)
User.create!(email: "producer@producer.com", password: "password", role: :producer)
User.create!(email: "admin@admin.com", password: "password", role: :admin)

# Create Podcasts
Podcast.create!(user: User.first, name: "Podcast 1", description: "Description 1", primary_category: "Category 1")
Podcast.create!(user: User.second, name: "Podcast 2", description: "Description 2", primary_category: "Category 2")
Podcast.create!(user: User.third, name: "Podcast 3", description: "Description 3", primary_category: "Category 3")

# Create Episodes
Episode.create!(podcast: Podcast.first, name: "Episode 1", number: 1, description: "Description 1", release_date: Date.today)
Episode.create!(podcast: Podcast.second, name: "Episode 2", number: 2, description: "Description 2", release_date: Date.today)
Episode.create!(podcast: Podcast.third, name: "Episode 3", number: 3, description: "Description 3", release_date: Date.today)
