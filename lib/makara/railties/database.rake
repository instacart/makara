namespace :db do
  task :load_config => ['makara:mask_adapter']
  task :drop => ['makara:mask_adapter']
  task :create => ['makara:mask_adapter']
  task :charset => ['makara:mask_adapter']
  
  namespace :schema do
    task :dump => ['makara:mask_adapter']
    task :load => ['makara:mask_adapter']
  end

  namespace :structure do
    task :dump => ['makara:mask_adapter']
    task :load => ['makara:mask_adapter']
  end

  namespace :drop do
    task :all => ['makara:mask_adapter']
  end

  namespace :create do
    task :all => ['makara:mask_adapter']
  end

  namespace :test do
    task :purge => ['makara:mask_adapter']
  end
end

namespace :makara do
  desc "force rake tasks to use pass-through db adapter"
  task :mask_adapter do
    Rails.application.config.database_configuration.each_pair do |env, config|
      if config["adapter"] == "makara"
        adapter = config["db_adapter"]

        config['adapter'] = adapter

        ActiveRecord::Base.configurations[env]["adapter"] = adapter if defined?(ActiveRecord::Base) && ActiveRecord::Base.configurations[env]
      end
    end
    Rake::Task["makara:mask_adapter"].reenable
  end
end
