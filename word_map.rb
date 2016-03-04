require 'nokogiri'
require 'pp'

$syn = IO.readlines('synonyms').map do |line|
  pair = line.split /\s+/
  Hash[pair[1], pair[0]]
end

$syn = $syn.inject{ |h1,h2| h1.merge(h2){ |*a| a[1,2] } }

def scan_words doc, selector
  doc.css(selector).map(&:content).map{|c| c.gsub(/[()!_:,.;"?*]|\s+/, ' ').split(/\s+/) }
end

# Array is an array of reviews/titles
# [['hey', 'this', 'is', 'a', 'review'], ['this', 'is', 'another']]
def words_from_array array
  skipped_words = IO.read('ignored').split(/\n+/)

  min_word = 3

  word_count = {}

  array.each do |word_array|
    word_array.each do |word|
      word.downcase!

      if !skipped_words.include?(word) && word.size > min_word

        word = $syn[word] if $syn[word]

        word_count[word] ||= 0
        word_count[word] += 1
      end
    end
  end

  word_count
end

def words_from_file file
  doc = Nokogiri::HTML(IO.read(file))

  reviews_words = scan_words(doc, 'font[size="2"][face="Arial"]')
  titles_words = scan_words(doc, 'p font[face="Arial"] b')

  paragraphs = words_from_array(reviews_words)
  titles = words_from_array(titles_words)

  {review: paragraphs, title: titles}
end

def most_common words, limit=7
  max = words.sort{|a,b| a[1] <=> b[1]}.last(limit).map { |w, c| "#{w}(#{c})" }
  max.reverse
end

Dir.glob('reviews/*.html').sort.each do |f|

  words = words_from_file(f)

  n = f.match(/reviews\/([0-9]+) \- .*/)[1].to_i

  puts f

  File.open("reviews/#{n}", 'w') do |file|
    file.puts most_common(words[:title]).join(' ')
    file.puts most_common(words[:review]).join(' ')
  end

end
