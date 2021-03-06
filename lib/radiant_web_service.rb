class RadiantWebService < ActionWebService::Base
  attr_accessor :controller

  def initialize(controller)
    @controller = controller
    @location = controller.url_for.split("/")[0..2].join("/")
  end

  def this_blog
    controller.send(:this_blog)
  end

  protected

  def authenticate(name, args)
    method = self.class.web_service_api.api_methods[name]

    begin
      h = method.expects_to_hash(args)
      raise "Invalid login" unless UserActionObserver.current_user = User.authenticate(h[:username], h[:password])
    rescue NoMethodError
      username, password = method[:expects].index(:username=>String), method[:expects].index(:password=>String)
      raise "Invalid login" unless UserActionObserver.current_user = User.authenticate(args[username], args[password])
    end
  end
end