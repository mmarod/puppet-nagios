require 'rubygems'
require 'nokogiri'
require 'open-uri'

module Puppet::Parser::Functions
  newfunction(:download_nsclient, :type => :rvalue) do |args|
    version = args[0]
    arch = args[1]

    vhost = 'files.nsclient.org'

    page = Nokogiri::HTML(open("http://#{vhost}/released/"))
    links = page.css('a').collect {|p| p["href"] }
    candidates = links.select {|l| l =~ /#{arch}.msi$/ }

    if version == 'latest'
      filename = candidates.last
    else
      filename = candidates.find { |e| /#{version}/ =~ e }
    end

    if ! File.exist?("C:\\nagios\\#{filename}")
      Net::HTTP.start(vhost) do |http|
        resp = http.get("/released/#{filename}")
        open("C:\\nagios\\#{filename}", "wb") do |file|
          file.write(resp.body)
        end
      end
    end

    return "C:\\nagios\\#{filename}"
  end
end
