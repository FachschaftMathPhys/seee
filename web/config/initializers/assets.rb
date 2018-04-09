# Be sure to restart your server when you modify this file.

# Version of your assets, change this if you want to expire all your assets.
Rails.application.config.assets.version = '1.0'

# Add additional assets to the asset load path.
# Rails.application.config.assets.paths << Emoji.images_path
# Add Yarn node_modules folder to the asset load path.
Rails.application.config.assets.paths << Rails.root.join('node_modules')

Rails.application.config.assets.precompile += %w( small_screen.css )
Rails.application.config.assets.precompile += %w( aceify-textareas.js )
Rails.application.config.assets.precompile += %w( viewer_count.js )
Rails.application.config.assets.precompile += %w( hitme_comment_preview.js )
Rails.application.config.assets.precompile += %w( ace/ace.js )
Rails.application.config.assets.precompile += %w( js-yaml.min.js )
Rails.application.config.assets.precompile += %w( json2yaml.js )
Rails.application.config.assets.precompile += %w( formeditor.js )
# Precompile additional assets.
# application.js, application.css, and all non-JS/CSS in the app/assets
# folder are already added.
# Rails.application.config.assets.precompile += %w( admin.js admin.css )
