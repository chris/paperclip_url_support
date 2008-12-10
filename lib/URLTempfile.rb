require 'mime/types'
require 'openssl'
require 'open-uri'


# This class provides a Paperclip plugin compliant interface for an "upload" file
# where that uploaded file is actually coming from a URL.  This class will download
# the file from the URL and then respond to the necessary methods for the interface,
# as required by Paperclip so that the file can be processed and managed by 
# Paperclip just as a regular uploaded file would.
#
class URLTempfile < Tempfile
  attr :content_type
  
  def initialize(url)
    @url = URI.parse(url)
    
    # see if we can get a filename
    raise "Unable to determine filename for URL uploaded file." unless original_filename

    begin
      # HACK to get around inability to set VERIFY_NONE with open-uri
      old_verify_peer_value = OpenSSL::SSL::VERIFY_PEER
      openssl_verify_peer = OpenSSL::SSL::VERIFY_NONE
      
      super('urlupload')
      Kernel.open(url) do |file|
        @content_type = file.content_type
        raise "Unable to determine MIME type for URL uploaded file." unless content_type
      
        self.write file.read
        self.flush
      end
    ensure
      openssl_verify_peer = old_verify_peer_value
    end
  end
  
  def original_filename
    # Take the URI path and strip off everything after last slash, assume this
    # to be filename (URI path already removes any query string)
    match = @url.path.match(/^.*\/(.+)$/)
    return (match ? match[1] : nil)
  end
  
  protected
  
  def openssl_verify_peer=(value)
    silence_warnings do
      OpenSSL::SSL.const_set("VERIFY_PEER", value)
    end
  end
end