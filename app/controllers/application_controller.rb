class ApplicationController < ActionController::Base
  include DeferredPosts
  helper_method :deferred_post_ids
end
