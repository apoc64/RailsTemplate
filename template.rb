# template.rb
# rails new wacky_widgets -m template.rb -T -d="postgresql"

gem "sorcery"

gem_group :development, :test do
  gem "pry"
  gem "active_designer"
end

gem_group :test do
  gem "capybara"
  gem "launchy"
  gem "rspec-rails"
  gem "shoulda-matchers"
  gem "simplecov"
end

git :init
git add: "."
git commit: %Q{ -m 'Initial commit' }
