#!/bin/ruby

def classy_exit
  puts "Gimme an html file"
  exit 0
end

def is_public_sf sf
  cmd = "sf2dump \"#{sf}\" 2>&1 | grep copyright -i | grep -i public"
  m = IO.popen(cmd).read

  m != ''
end


def hyperlink link
  "\"=HYPERLINK(\"#{link}\";\"#{link}\")\""
end
classy_exit if ARGV[0].nil?

require 'nokogiri'
require './html2markdown'
require 'pp'

wayback_string = /\/web\/[0-9]+\//
file_folder = './hammersound/'
mirror_base = 'http://www.ibiblio.org/thammer/HammerSound/localfiles/soundfonts/'

csv = {
  name: [],
  description: [],
  author: [],
  mirrors: [],
  file: [],
  software_list: [],
  tag_list: [],
  file_format_list: [],
  more_info_urls: [],
  license: [],
  rating: [],
  review_number: [],
  number_of_reviews: [],
  review_titles: [],
  review_bodies: []
}

doc = Nokogiri::HTML(IO.read(ARGV[0]).gsub(wayback_string, '').gsub(/\n/, '').gsub(/Submitted By: (.*?)<\/font>/, '<\/font>'))

doc.css('tbody').each do |node|
  csv[:name] << node.css('tr td:nth-child(2) strong').map do |l|
    l.content.gsub(/\s\s+/, ' ').gsub(/\[.*\]\s+$|\(.*\)\s+$/, '').strip!
  end.first.to_s

  csv[:description] << node.css('tr:nth-child(2) td[bgcolor="#808080"]:nth-child(2)').map do |l|
    "#{HTML2Markdown.new(l.inner_html.gsub(/\s\s+/, ' ')).to_s.strip!.gsub(/\n\n+/, "\n").chomp}"
  end.first.to_s

  csv[:author] << node.css('tr:nth-child(3) td:first-child').map do |l|
    l.content.gsub(/\s+/, " ").match(/ Author:\s+([^|,]*)/)[1].strip!
  end.first.to_s

  csv[:more_info_urls] << node.xpath('tr[position()=3]/td[position()=1]/font/a[contains(text(), \'Homepage\')]').map do |l|
    l.attr('href')
  end.first.to_s

  csv[:file] << node.xpath('tr[position()=2]/td/a[position()=last()]').map do |l|
    l.attr('href').split('/')[-1].split('=')[-1]
  end.first.to_s

  csv[:mirrors] = csv[:file].map { |l| "#{mirror_base}#{l}" }

  csv[:file] = csv[:file].map {|l| l.downcase.gsub("%20", " ").gsub(/\.sfark$|\.sfpack|\.zip|\.rar|\.sbk$/, '.sf2')}

  csv[:software_list] << ['linuxsampler', 'carla', 'fluidsynth', 'timidity']

  csv[:tag_list] << [ARGV[0].match(/html_pages\/([a-z_]+)[0-9]?\.html/)[1], 'soundfont']

  csv[:file_format_list] << ['sf2']

  csv[:missing] = csv[:file].map { |file| !File.exists?("#{file_folder}#{file}") }

  if is_public_sf("#{file_folder}#{csv[:file].last}")
    csv[:license] << 'public'
  else
    csv[:license] << ''
  end

  csv[:rating] << node.css('tr:first-child td:nth-child(3)').map { |l| l.content.gsub(/\s+Rating: ([0-9.]+) \([0-9]+\)\s+/, '\1') }.first

  csv[:rating] = csv[:rating].map { |rating| rating == "\t\t    Rate it" ? '' : rating }

  csv[:number_of_reviews] << node.css('tr:first-child td:nth-child(3)').map { |l| l.content.gsub(/\s+Rating: [0-9.]+ \(([0-9]+)\)\s+/, '\1') }.first

  csv[:number_of_reviews] = csv[:number_of_reviews].map { |rating| rating == "\t\t    Rate it" ? '' : rating }

  csv[:review_number] << node.css('tr:first-child td:nth-child(3) a').map { |l| l.attr('href').gsub(/http:\/\/.*SoundFont_Index=([0-9]+)$/, '\1') }.first

  csv[:review_link] = csv[:review_number].map { |n| "https://web.archive.org/web/20081007071957/http://www.hammersound.com/cgi-bin/review.pl?action=view_reviews;SoundFont_Index=#{n}" }

end

csv[:review_number].each do |n|

  begin
    lines = IO.readlines("reviews/#{n}")

    csv[:review_titles] << lines[0].chomp
    csv[:review_bodies] << lines[1].chomp

  rescue Errno::ENOENT
    csv[:review_titles] << ''
    csv[:review_bodies] << ''
  end

end

if ARGV[1] == 'doit'
  0.upto(csv[:name].size - 1) do |i|
    file = "#{file_folder}#{csv[:file][i]}"
    puts "
  #{"# ------- File is missing #{csv[:file][i]} " if csv[:missing][i] }
  Artifact.create(
      name: #{csv[:name][i].to_s.gsub(/\s+$/, '').inspect},
      description: #{csv[:description][i].inspect},
      tag_list: #{csv[:tag_list][i].inspect},
      software_list: #{csv[:software_list][i].inspect},
      mirrors: #{csv[:mirrors][i].inspect},
      file: File.open(#{file.inspect}) ,
      author: #{csv[:author][i].inspect},
      license: License.where(short_name: #{csv[:license][i].inspect}).first,
      user: User.first,
      file_format_list: #{csv[:file_format_list][i].inspect},
      more_info_urls: #{csv[:more_info_urls][i].inspect}
  "
  end
elsif ARGV[1] == 'files'
  csv[:file].each_with_index do |f, i|
    filename = "#{file_folder}/#{f}"
    if csv[:missing][i]
      puts "-- #{f} - #{csv[:name][i]} is missing."
    end
  end
elsif ARGV[1] == 'csv'
  0.upto(csv[:name].size - 1) do |i|
  if csv[:rating][i] != ''
    rating = "#{csv[:rating][i]} / #{csv[:number_of_reviews][i]}"
  else
    rating = ''
  end
puts [
  csv[:name][i].to_s.gsub(/\s+$/, '').inspect,
  csv[:description][i].gsub("\n", ' ').gsub('"', "'").inspect,
  csv[:author][i].inspect,
  csv[:file][i].inspect,
  "#{csv[:missing][i] ? 'no file' : ''}".inspect,
  csv[:license][i].inspect,
  rating.inspect,
  csv[:tag_list][i].join(', ').inspect,
  csv[:review_titles][i].inspect,
  csv[:review_bodies][i].inspect,
  csv[:review_link][i].inspect,
  csv[:more_info_urls][i].inspect,
  "https://data.musical-artifacts.com/hammersound/#{csv[:file][i]}".inspect,
].join(',')
  end
else
  pp csv
end