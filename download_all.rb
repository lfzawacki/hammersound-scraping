
list = IO.read('text_files/ftp-list').split(/\n+/)
folder = './hammersound/'
url = "http://www.ibiblio.org/thammer/HammerSound/localfiles/soundfonts/"

list.each do |file|

  filename = "#{folder}#{file}"
  if File.exists?(filename)
    # print "."
  else
    # print "x"
    puts "Downloading #{file} ..."
    # system "curl \"#{url}#{file}\" -o \"#{filename}\" -L"
  end

end

puts
