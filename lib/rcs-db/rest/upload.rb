require 'tmpdir'

module RCS
module DB

class UploadController < RESTController

  def create
    require_auth_level :tech

    # TODO: handle the http multipart-upload... :(

=begin
------------GI3ae0ei4Ij5GI3KM7GI3cH2KM7Ef1
Content-Disposition: form-data; name="Filename"

Macosx Client.txt
------------GI3ae0ei4Ij5GI3KM7GI3cH2KM7Ef1
Content-Disposition: form-data; name="Filedata"; filename="Macosx Client.txt"
Content-Type: application/octet-stream

sudo bash
cd "/Library/Application Support/VMware Fusion/isoimages"
mkdir original
mv darwin.iso tools-key.pub *.sig original
perl -n -p -e 's/ServerVersion.plist/SystemVersion.plist/g' < original/darwin.iso > darwin.iso
openssl genrsa -out tools-priv.pem 2048
openssl rsa -in tools-priv.pem -pubout -out tools-key.pub
openssl dgst -sha1 -sign tools-priv.pem < darwin.iso > darwin.iso.sig
for A in *.iso ; do openssl dgst -sha1 -sign tools-priv.pem < $A > $A.sig ; done
exit
------------GI3ae0ei4Ij5GI3KM7GI3cH2KM7Ef1
Content-Disposition: form-data; name="Upload"

Submit Query
------------GI3ae0ei4Ij5GI3KM7GI3cH2KM7Ef1--#
=end

    t = Time.now
    name = @session[:user][:_id].to_s + "-" + "%10.9f" % t.to_f
    path = File.join Dir.tmpdir, name

    File.open(path, "wb+") do |f|
      f.write @request[:content]
    end

    Audit.log :actor => @session[:user][:name], :action => 'upload.create', :desc => "Uploaded #{@request[:content].size.to_s_bytes} bytes"

    return RESTController.reply.ok(name, {:content_type => 'text/plain'})
  end

end

end # ::DB
end # ::RCS
