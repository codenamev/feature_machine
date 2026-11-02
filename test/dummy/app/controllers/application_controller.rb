# A fresh host's ApplicationController, and nothing more: no current_user, no
# admin base, no API base. The engine has to bring everything else itself.
class ApplicationController < ActionController::Base
end
