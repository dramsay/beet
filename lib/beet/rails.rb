module Beet
  module Rails
    # Make an entry in Rails routing file conifg/routes.rb
    #
    # === Example
    #
    #   route "map.root :controller => :welcome"
    #
    def route(routing_code)
      log 'route', routing_code
      sentinel = 'ActionController::Routing::Routes.draw do |map|'

      in_root do
        gsub_file 'config/routes.rb', /(#{Regexp.escape(sentinel)})/mi do |match|
          "#{match}\n  #{routing_code}\n"
        end
      end
    end

    # Add Rails to /vendor/rails
    #
    # ==== Example
    #
    #   freeze!
    #
    def freeze!(args = {})
      log 'vendor', 'rails edge'
      in_root { run('rake rails:freeze:edge', false) }
    end

    # Install a plugin.  You must provide either a Subversion url or Git url.
    # For a Git-hosted plugin, you can specify if it should be added as a submodule instead of cloned.
    #
    # ==== Examples
    #
    #   plugin 'restful-authentication', :git => 'git://github.com/technoweenie/restful-authentication.git'
    #   plugin 'restful-authentication', :git => 'git://github.com/technoweenie/restful-authentication.git', :submodule => true
    #   plugin 'restful-authentication', :svn => 'svn://svnhub.com/technoweenie/restful-authentication/trunk'
    #
    def plugin(name, options)
      log 'plugin', name

      if options[:git] && options[:submodule]
        in_root do
          Git.run("submodule add #{options[:git]} vendor/plugins/#{name}")
        end
      elsif options[:git] || options[:svn]
        in_root do
          run_ruby_script("script/plugin install #{options[:svn] || options[:git]}", false)
        end
      else
        log "! no git or svn provided for #{name}.  skipping..."
      end
    end

    # Adds an entry into config/environment.rb for the supplied gem :
    def gem(name, options = {})
      log 'gem', name
      env = options.delete(:env)

      gems_code = "config.gem '#{name}'"

      if options.any?
        opts = options.inject([]) {|result, h| result << [":#{h[0]} => #{h[1].inspect.gsub('"',"'")}"] }.sort.join(", ")
        gems_code << ", #{opts}"
      end

      environment gems_code, :env => env
    end

    # Adds a line inside the Initializer block for config/environment.rb. Used by #gem
    # If options :env is specified, the line is appended to the corresponding
    # file in config/environments/#{env}.rb
    def environment(data = nil, options = {}, &block)
      sentinel = 'Rails::Initializer.run do |config|'

      data = block.call if !data && block_given?

      in_root do
        if options[:env].nil?
          gsub_file 'config/environment.rb', /(#{Regexp.escape(sentinel)})/mi do |match|
            "#{match}\n  " << data
          end
        else
          Array.wrap(options[:env]).each do|env|
            append_file "config/environments/#{env}.rb", "\n#{data}"
          end
        end
      end
    end

    # Create a new file in the vendor/ directory. Code can be specified
    # in a block or a data string can be given.
    #
    # ==== Examples
    #
    #   vendor("sekrit.rb") do
    #     sekrit_salt = "#{Time.now}--#{3.years.ago}--#{rand}--"
    #     "salt = '#{sekrit_salt}'"
    #   end
    #
    #   vendor("foreign.rb", "# Foreign code is fun")
    #
    def vendor(filename, data = nil, &block)
      log 'vendoring', filename
      file("vendor/#{filename}", data, false, &block)
    end


    # Create a new initializer with the provided code (either in a block or a string).
    #
    # ==== Examples
    #
    #   initializer("globals.rb") do
    #     data = ""
    #
    #     ['MY_WORK', 'ADMINS', 'BEST_COMPANY_EVAR'].each do
    #       data << "#{const} = :entp"
    #     end
    #
    #     data
    #   end
    #
    #   initializer("api.rb", "API_KEY = '123456'")
    #
    def initializer(filename, data = nil, &block)
      log 'initializer', filename
      file("config/initializers/#{filename}", data, false, &block)
    end

    # Generate something using a generator from Rails or a plugin.
    # The second parameter is the argument string that is passed to
    # the generator or an Array that is joined.
    #
    # ==== Example
    #
    #   generate(:authenticated, "user session")
    #
    def generate(what, *args)
      log 'generating', what
      argument = args.map {|arg| arg.to_s }.flatten.join(" ")

      in_root { run_ruby_script("script/generate #{what} #{argument}", false) }
    end
  end # Rails
end # Beet
