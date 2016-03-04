require 'open-uri'
require 'nokogiri'

base_url = "https://web.archive.org/web/20081007071957/http://www.hammersound.com/cgi-bin/review.pl?action=view_reviews;SoundFont_Index="
base_path = "reviews"

(0..1500).each do |n|
    begin
      doc = Nokogiri::HTML(open("#{base_url}#{n}"))

      title = ''

      l = doc.css('b').first
      m = l.content.match(/\s+Reviews for SoundFont \"(.*)\" \[(.*)\]\s+/)
      title = "#{base_path}/#{sprintf("%04d", n)} - #{m[2]} - #{m[1].gsub("/", '')}.html"

      if !File.exists?(title)
          puts "Doing #{m[1]} ..."

          File.open(title, 'w') do |f|
            f << doc.to_html
          end
      else
        puts "Skipping #{m[1]}"
      end

    rescue OpenURI::HTTPError => e
      puts "ERROR on review #{n} #{e.message}"
    end
end
