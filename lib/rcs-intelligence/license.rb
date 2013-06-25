# encoding: utf-8
#
#  License handling stuff
#

# from RCS::Common
require 'rcs-common/trace'
require 'rcs-common/crypt'

class LicenseManager
  include Singleton
  include RCS::Tracer

  def check(field)

    case (field)

      when :alerting
        return @limits['alerting']

      when :archive
        return @limits['archive']

      when :ocr
        return @limits['ocr']

      when :translation
        return @limits['translation']

      when :correlation
        return @limits['correlation']

      when :intelligence
        return @limits['intelligence']

      when :connectors
        return @limits['connectors']
    end

    return false
  end

  def load_from_db
    db = RCS::DB::DB.instance.mongo_connection
    @limits = db['license'].find({}).first
  end

end

