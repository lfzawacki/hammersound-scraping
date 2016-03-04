#/bin/ruby

word = ARGV[0] || ''

puts word.gsub('.html', '').split('_').map(&:capitalize).join(' ')