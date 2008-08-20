require 'mime/types'
require 'net/https'

# This class provides a Paperclip plugin compliant interface for an "upload" file
# where that uploaded file is actually coming from a URL.  This class will download
# the file from the URL and then respond to the necessary methods for the interface,
# as required by Paperclip so that the file can be processed and managed by 
# Paperclip just as a regular uploaded file would.
#
# TODO: support redirects
# TODO: handle lack of OpenSSL/HTTPS
# TODO: if identify app not available, use file extension (if avail) or other 
#       mechanism to get content_type
class URLTempfile < Tempfile
    
  def initialize(url)
    @url = URI.parse(url)
    
    # see if we can get a filename
    raise "Unable to determine filename for URL uploaded file." unless original_filename
    
    # Create a tempfile and download the image specified in the URL into it
    super('urlupload')
    request = Net::HTTP.new(@url.host, @url.port)
    request.use_ssl = (@url.scheme == 'https')
    request.verify_mode = OpenSSL::SSL::VERIFY_NONE
    self.write request.get(@url.request_uri).body
    self.flush
    
    raise "Unable to determine MIME type for URL uploaded file." unless content_type
  end
  
  def original_filename
    # Take the URI path and strip off everything after last slash, assume this
    # to be filename (URI path already removes any query string)
    match = @url.path.match(/^.*\/(.+)$/)
    return (match ? match[1] : nil)
  end
  
  def content_type
    begin
      info = `identify "#{path}"`
      Rails.logger.debug "identify results for (#{path}): #{info}"
      raise "Failed running identify on #{@url}" if info.empty?
      return MIME::Types.type_for(info.split[1]).first.simplified
    rescue => e
      Rails.logger.error "Unable to determine content type for URL uploaded file: #{e.message}"
      nil
    end
  end
    
end