class AppSecret < ActiveRecord::Base
  validates_presence_of :name, :value
  validates_uniqueness_of :name

  def self.secret(name)
    random = ActiveSupport::SecureRandom.hex(64)
    if $server_mode
      find_or_create_by_name(name, :value => random).value
    else
      random
    end
  end
end
