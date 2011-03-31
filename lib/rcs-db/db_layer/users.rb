#
# Mix-in for DB Layer
#

require 'digest/sha1'

module DBLayer
module Users

  def user_find(user)
    #TODO: implement this
    u = {'user' => 'test-user',
         'pass' => Digest::SHA1.hexdigest('.:RCS:.' + 'test-pass'),
         'description' => "User for test",
         'contact' => 'test@me.it',
         'enabled' => true,
         'level' => [:viewer, :tech]}
    
    return u
  end

  def user_check_pass(pass, digest)
    # we use the SHA1 with a salt '.:RCS:.' to avoid rainbow tabling
    return digest == Digest::SHA1.hexdigest('.:RCS:.' + pass)
  end

end # ::Users
end # ::DBLayer