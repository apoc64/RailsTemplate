#Hey!

Hi me, or you if you're not me. These instructions will setup a Rails 6 project with sorcery for auth and rspec for testing. You should have homebrew for managing installations, a ruby version manager such as rbenv or rvm (not both), Postgres, RubyGems, the gem bundler for Ruby package management, and Rails.

Verify local versions of Ruby(2.6.3) and Rails(6.0.2.1), switch if necessary:
```
ruby -v
rails -v
```
To create a new rails project with added gems from the template in this repo, run:
`rails new wacky_widgets -m template.rb -T -d="postgresql"`

cd into the directory of the new project and install rspec
`rails g rspec:install`

To enable ShouldaMatchers test helpers, in rails_helper add:
```
Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end
```
Also a good time to delete boilerplate code.

To enable SimpleCov test coverage, in spec_helper add:
```
require 'simplecov'

SimpleCov.start 'rails' do
  add_filter '/bin/'
  add_filter '/db/'
  add_filter '/spec/'
end
```

To the gitignore add:
```
/coverage
/active_designer
.DS_store
```

To create a Sorcery user, run:
`rails g sorcery:install remember_me reset_password`

After this, add any new fields you want to the first new migration file:
```
...
  t.string :name
  t.integer :role, default: 0
...
```

Create the database and run the migrations:
```
rake db:create
rake db:migrate
```

Inside config/sorcery.rb, comment out until you are ready for the modules:
`# Rails.application.config.sorcery.submodules = [:remember_me, :reset_password]`


Try to run the server, but you may need to install webpacker to handle js packages. If you don't have them installed, run:
```
brew install node
brew install yarn
```
Then install webpacker:
`rake webpacker:install`

Run the server:
`rails s`
Then visit http://localhost:3000 in the browser.
You might clean up the gemfile and delete boilerplate comments.

Write user model tests. Inside /spec, create /models/user_spec.rb, and add:
```
require 'rails_helper'

describe User, type: :model do
  describe "validations" do
    it { should validate_presence_of (:email) }

    it 'only saves users with strong passwords' do
      user = User.create(email: 'bob@bob.bob', password: '1234')
      expect(user.persisted?).to eq(false)

      user = User.create(email: 'bob@bob.bob', password: '1234abcd')
      expect(user.persisted?).to eq(false)

      user = User.create(email: 'bob@bob.bob', password: '1234Abcd')
      expect(user.persisted?).to eq(false)

      user = User.create(email: 'bob@bob.bob', password: '1234Abcdef')
      expect(user.persisted?).to eq(false)

      user = User.create(email: 'bob@bob.bob', password: '123456789!')
      expect(user.persisted?).to eq(false)

      user = User.create(email: 'bob@bob.bob', password: 'qwertyuio!')
      expect(user.persisted?).to eq(false)

      expect(User.all.count).to eq(0)

      user = User.create(email: 'bob@bob.bob', password: '1234Abc!')
      expect(user.persisted?).to eq(true)
      expect(User.all.count).to eq(1)
    end
  end
end
```

Run the tests:
`rspec`

To pass them, inside app/models/user.rb, add:
```
validates_presence_of :email
validates_uniqueness_of :email
validate :password_complexity

enum role: %i[default admin]

private

def password_complexity
  return if password.blank? || password =~ /^(?=.*?[A-Z])(?=.*?[a-z])(?=.*?[0-9])(?=.*?[#?!@$%^&*-]).{8,70}$/
  errors.add :password, 'Password must be 8-70 characters, and contain at least one lowercase, uppercase, number, and special character'
end
```
(Email is already validated at the database layer)

Commit "Creates user"

Write a user feature test. First, inside /spec, create test_helpers.rb:
```
module TestHelpers
  module Features
    def new_bob
      User.create(email: 'bob@bob.bob', password: 'Bob1234!', name: 'Bob')
    end

    def new_barb
      User.create(email: 'barb@barb.barb', password: 'Barb321!', name: 'Barb')
    end

    def login_bob
      user = new_bob

      visit root_path
      expect(page).to_not have_content('Log Out')
      expect(page).to have_button('Log In')

      within('nav') do
        fill_in :email, with: user.email
        fill_in :password, with: 'Bobby1234!'
        click_on 'Log In'
      end

      user
    end

    def login_user(user, password)
      visit root_path

      within('nav') do
        fill_in :email, with: user.email
        fill_in :password, with: password
        click_on 'Log In'
      end

      current_path == user_path(user)
    end
  end
end
```
And in rails_helper, below require rspec/rails, add:
`require 'test_helpers'` and inside the rspec config block, add:
```
config.include TestHelpers::Features, type: :feature
config.include TestHelpers::Features, type: :request
```

Inside /spec, create /features/user_login_spec.rb, and add:
```
require 'rails_helper'

describe 'user login' do
  it 'filling out login form on root path takes user to show path' do
    user = new_bob
    expect(user.role).to eq('default')

    visit root_path

    expect(page).to_not have_content('Log Out')
    expect(page).to have_button('Log In')

    within('nav') do
      fill_in :email, with: user.email
      fill_in :password, with: 'Bob1234!'
      click_on 'Log In'
    end

    expect(current_path).to eq(user_path(user))
    expect(page).to have_content('Hi Bob')
    expect(page).to have_content('Logged in successfully')
    expect(page).to have_content('Log Out')
    expect(page).to_not have_content('Invalid email or password')
    expect(page).to_not have_button('Log In')
  end

  it 'prevents users from logging in with wrong password' do
    user = new_bob
    visit root_path

    expect(page).to_not have_content('Log Out')
    expect(page).to have_button('Log In')

    within('nav') do
      fill_in :email, with: user.email
      fill_in :password, with: '125'
      click_on 'Log In'
    end

    expect(current_path).to_not eq(user_path(user))
    expect(page).to_not have_content('Hi Bob')
    expect(page).to_not have_content('Logged in successfully')
    expect(page).to_not have_content('Log Out')
    expect(page).to have_content('Invalid email or password')
    expect(page).to have_button('Log In')
  end

  it 'prevents guests from seeing user show' do
    user = new_bob

    visit user_path(user)

    expect(current_path).to eq(root_path)
    expect(page).to have_button('Log In')
    expect(page).to_not have_content('Log Out')
    expect(page).to have_content('Access Denied')
  end

  it 'allows user to logout' do
    user = login_bob

    expect(current_path).to eq(user_path(user))
    expect(page).to have_content('Bob')

    within('nav') do
      click_on 'Log Out'
    end

    expect(current_path).to eq(root_path)
    expect(page).to have_button('Log In')
    expect(page).to_not have_content('Log Out')
    expect(page).to have_content('Logged out successfully')

    visit user_path(user)

    expect(current_path).to eq(root_path)
    expect(page).to have_content('Access Denied')
  end

  it 'prevents logged in user from seeing another user show' do
    user = new_barb
    login_bob

    visit user_path(user)

    expect(current_path).to eq(root_path)
    expect(page).to have_content('Access Denied')
  end

end
```
Fail the test, and continue to run rspec at each step to verify progress.

Add user routes to routes.rb:
```
root to: 'home#index'
resources :sessions, only: [:create, :destroy]
resources :users, only: [:show]
```

In /app/controllers, create home_controller.rb:
```
class HomeController < ApplicationController

  def index
  end

end
```
In /app/views, create /home/index.html.erb:
`<p>Welcome to the site</p>`

We will handle login and logout in the nav bar, to views/layouts/application.html.erb, first add Materialize and icons to the head above the Rails links:
```
<link href="https://fonts.googleapis.com/icon?family=Material+Icons" rel="stylesheet">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0-beta/css/materialize.min.css">
<script src="https://cdnjs.cloudflare.com/ajax/libs/materialize/1.0.0-beta/js/materialize.min.js"></script>
```

Then add a navbar to the body:
```
<div class="navbar-fixed">
    <nav class="red darken-4">
      <div class="container">
        <div class="nav-wrapper">
          <%= link_to "Wacky Widgets", root_path %>
          <a href="#" data-target="mobile-nav" class="sidenav-trigger">
            <i class="material-icons">menu</i>
          </a>
          <ul class="right hide-on-med-and-down">
            <% if logged_in? %>
              <li><%= link_to "My Profile", user_path(current_user) %></li>
              <li><%= link_to "Log Out", session_path(current_user), method: :delete %></li>
            <% else %>
              <%= form_tag sessions_path do %>
              <li><%= text_field_tag :email, params[:email], placeholder: 'Email', id: 'nav-email' %></li>
              <li><%= password_field_tag :password, params[:password], placeholder: 'Password', id: 'nav-password' %></li>
              <li><%= submit_tag 'Log In', class: 'btn-small red darken-1' %></li>
              <% end %>
            <% end %>
          </ul>
        </div>
      </div>
    </nav>
  </div>
  <ul class="sidenav" id="mobile-nav">
    <% if logged_in? %>
      <li><%= link_to "My Profile", user_path(current_user) %></li>
      <li><%= link_to "Log Out", session_path(current_user), method: :delete %></li>
    <% else %>
      <%= form_tag sessions_path do %>
      <li><%= text_field_tag :email, params[:email], placeholder: 'Email', id: 'sidenav-email' %></li>
      <li><%= password_field_tag :password, params[:password], placeholder: 'Password', id: 'sidenav-password' %></li>
      <li><%= submit_tag 'Log In', class: 'btn-small red darken-1' %></li>
      <% end %>
    <% end %>
  </ul>
<div class="container">
<% flash.each do |type, message| %>
  <p class=<%= type %>><%= message %></p>
<% end %>
<%= yield %>
</div>
```
Note - <%= yield %> is already there. Don't duplicate it.

Inside /assets/stylesheets/application.css, add:
```
#nav-email, #nav-password {
 background-color: white;
 margin: .5em;
 padding: .5em;
 height: 70%;
 width: 85%;
}

#sidenav-email, #sidenav-password {
  margin: .5em;
}

.alert {
  padding: 1em;
  background-color: #ffcccc;
}

.notice {
  padding: 1em;
  background-color: #90ee90;
}
```
And to /app/packs/application.js (not the encouraged location):
```
document.addEventListener('DOMContentLoaded', function() {
  const sideNav = document.querySelector('.sidenav');
  M.Sidenav.init(sideNav, {});
  var elems = document.querySelectorAll('select');
  var instances = M.FormSelect.init(elems);
});
```

TODO: - Figure out Rails 6 Materialize js init issue

Inside app/controllers, create sessions_controller.rb:
```
class SessionsController < ApplicationController

  def create
    user = login(session_params[:email], session_params[:password])
    if user
      redirect_to user_path(user), notice: 'Logged in successfully'
    else
      redirect_to root_path, alert: 'Invalid email or password'
    end
  end

  def destroy
    logout
    redirect_to root_path, notice: 'Logged out successfully'
  end

  private

  def session_params
    params.permit(:email, :password)
  end

end
```

Create users_controller.rb:
```
class UsersController < ApplicationController
  before_action :require_login

  def show
    not_authenticated unless current_user.id == params[:id].to_i
    @user = current_user
  end
end
```

Add a helper to application_controller:
```
private

def not_authenticated
  redirect_to root_path, alert: 'Access Denied'
end
```

Inside /app/views, create /users/show.html.erb:
```
<h3>Hi <%= @user.name %></h3>
```

Pass the tests. If necessary, run rails s, then visit localhost:3000 to see the home screen. To create a user from the console, run:
`rails c`
From the Rails console, run:
`User.create(email: 'bob@bob.bob', password: 'Bob1234!', name: 'Bob')`
Login and logout from the browser.

Commit "User can login and out"

To scaffold a widget, run:
`rails g scaffold widget name:string description:text picture:string color:integer is_public:boolean user:belongs_to`
then:
`rake db:migrate`
Delete scaffold css, remove notices from index and show views, commit, add passing relationship tests, add failing tests for changes. Checkboxes will require html changes to work with Materialize. Add navbar links for widgets

To view the data model visualization using ActiveDesigner, run:
`active_designer --create ./db/schema.rb`

To view test coverage using SimpleCov, open /coverage/index.html in the browser
