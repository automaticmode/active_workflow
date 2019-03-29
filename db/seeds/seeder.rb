class Seeder
  def self.seed
    user = User.find_or_initialize_by(email: ENV['SEED_EMAIL'].presence || 'admin@example.com')
    if user.persisted?
      puts "User with email '#{user.email}' already exists, not seeding."
      exit
    end

    user.username = ENV['SEED_USERNAME'].presence || 'admin'
    user.password = ENV['SEED_PASSWORD'].presence || 'password'
    user.password_confirmation = ENV['SEED_PASSWORD'].presence || 'password'
    user.admin = true
    user.save!

    unless DefaultWorkflowImporter.seed(user)
      raise('Unable to import the default workflow')
    end
  end
end
