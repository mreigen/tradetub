module Paperclip
  class AutoOrient < Paperclip::Processor 
    require 'RMagick' # Make sure to update your gem file

    def initialize(file, options = {}, *args)
      @file = file
    end

    def make( *args )
      img = Magick::Image.read("#{File.expand_path(@file.path)}")[0]
      img.auto_orient!

      temp = Tempfile.new(@file.path.split('/').last)
      img.write(temp.path)
      return temp
    end
  end
end