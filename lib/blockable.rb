require 'octokit'

class ConnectError < StandardError
end

class AccessError < StandardError
end

module Blockable
  
  def client
    @client ||= Octokit::Client.new({:login => self.login, 
      :oauth_token => token, 
      :per_page => 100,
      :auto_traversal => true  }) 
  end
  
  def login
    # get the login
    @login ||= get_auth.first
  end
  
  def token
    # get the token
    @token ||= get_auth.last
  end
  
  def get_auth(path="")
    # load the authentication info and return it
    # TODO: Allow password auth (maybe?)
    # TODO: Prompt if file not found
    if path == ""
      cf_file = File.join(File.dirname(__FILE__), '..', 'config', 'configuration.yml')
    else
      cf_file = path 
    end
    if File.exist?(cf_file) 
      config = YAML::load_file(cf_file)
      section = config['github_nuclear']
      [section['login'], section['oauth_token']]
    else
      raise ConnectError, "Config file not found"
    end
  end
  
  def expire(token)
    @cache.delete_if { |key, value| key.include?(token) }
  end
  
  def is_fork?(repository)
    get_repository(repository)[:fork]
  end

  def source_repo(repository)
    # given a fork name (:full_name), return the parent
    if is_fork?(repository)
      # get the fork from GitHub (should be cached from the is_fork? call)
      repo = get_repository(repository)
      # get the parent from GitHub
      get_repository(repo[:parent][:full_name])
    else
      get_repository(repository)
    end
  end
  
  def my_fork(repository_name)
    client.repositories().each do |repo|
      if repo[:name] == repository_name
        return get_repository(repo[:full_name])
      end
    end
  end
  
  def clear_cache
    @cache = {}
  end
  
  def get_repository(repository)
    # get a repository from the octokit client
    unless defined?(@cache)
      @cache = {}
    end
    unless @cache["#{repository}"]
      # cache the pull
      begin
        @cache["#{repository}"] = client.repository(repository)  
      rescue Octokit::NotFound
        raise AccessError, "Cannot access #{repository} - check that the leaver user is in a team with visibility"
      end
    end
    @cache["#{repository}"]
  end
  
  def get_branches(repository)
    # get branches from the octokit client
    unless defined?(@cache)
      @cache = {}
    end
    unless @cache["#{repository}_branches"]
      # cache the pull
      @cache["#{repository}_branches"] = client.branches(repository)  
    end
    @cache["#{repository}_branches"]
  end

  def get_commits(repository, branch)
    # get commits for branch from the octokit client
    unless defined?(@cache)
      @cache = {}
    end
    unless @cache["#{repository}_#{branch}_commits"]
      # cache this 
      @cache["#{repository}_#{branch}_commits"] = client.commits(repository, branch)
    end
    @cache["#{repository}_#{branch}_commits"]
  end
  
  
end