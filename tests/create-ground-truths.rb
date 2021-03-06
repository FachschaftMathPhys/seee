#!/usr/bin/env ruby

require 'pp'
require 'rubygems'
require 'gtk2'
require 'tempfile'
require 'yaml'
require 'dbi'
require '../lib/AbstractForm.rb'
require '../pest/helper.AbstractFormExtended.rb'
require '../pest/helper.image.rb'

class CreateGroundTruths
  include PESTImageTools

  WINTITLE_PREFIX = "Create ground truths | E=empty; F=checked; B=barely; V=overfull"

  # finds all files that still need ground truths to be defined. Files
  # are returned as hash, with the key being the base YAML file and the
  # value being an array of files to process.
  def find_suitable_files
    x = {}
    Dir.glob("omr-test/*.yaml") do |base|
      subdir = File.basename(base, ".yaml")
      images = Dir.glob("omr-test/#{subdir}/*.tif").reject do |img|
        File.exists?("omr-test/#{subdir}/#{File.basename(img, ".tif")}_ref.yaml")
      end
      x[base] = images unless images.empty?
    end
    x
  end

  # returns the amount of pages in the currently loaded YAML file
  def page_count
    @yaml.pages.count
  end

  def draw_box_to_pixbuf
    # 40 pixels is the size of a @box on 300 DPI scans. Include a large
    # enough area so we don’t need to fine tune. Also, TeX places the
    # @box on the bottom left, so decrease the first top left coordinate.
    if @box.height.nil? || @box.width.nil?
      coord = correct(@page_index, [@box.x-40*1.5, @box.y-40]) + [40*2, 40*1.5]
      img = @ilist[@page_index].crop(*coord)
    else
      # width and height for comment boxes are actually coordinates, that
      # need to be fixed. Grep this: WIDTH_HEIGHT_AS_COORDINATE
      @box.width -= @box.x
      @box.height = PAGE_HEIGHT*@dpifix - @box.height - @box.y
      coord = correct(@page_index, [@box.x-50, @box.y-50]) + [@box.width+100, @box.height+100]
      img = @ilist[@page_index].crop(*coord)
    end

    # Hack! Hack! Writing it to disk and reading it again is still
    # faster than an in-memory way. Partly because Gdk's import
    # functions suck and partly due to RMagick's to_blob being very
    # slow
    temp = Tempfile.new("image.jpg")
    img.write("jpg:"+ temp.path)
    @pixbuf = Gdk::Pixbuf.new(temp.path)

    # Invalidate area if possible. This may not be the case when the
    # app starts up, but draw_image_to_screen will be called automatically any-
    # way, so we don't need to bother at this point
    return if @area == nil || @area.window == nil
    @area.queue_draw_area(0, 0, @area.window.size[0], @area.window.size[1])
  end

  def draw_image_to_screen
    return if @pixbuf == nil
    gc = @window.style.fg_gc(@area.state)

    maxw = Float.induced_from(@area.window.size[0])
    maxh = Float.induced_from(@area.window.size[1])

    imgw = @pixbuf.width
    imgh = @pixbuf.height

    # Return if the area is so small that its illegible  or if the
    # source image is broken somehow
    return if maxw <= 50 || maxh <= 50 || imgw == 0 || imgh == 0

    # Don't scale up
    if maxw < imgw || maxh < imgh
      # and keep the aspect ratio
      aspect = imgh.to_f / imgw.to_f;
      if aspect < maxh / maxw
        imgw = Math.min(imgw, maxw);
        imgh = (imgw * aspect).round;
      else
        imgh = Math.min(imgh, maxh);
        imgw = (imgh / aspect).round;
      end
    end
    @area.window.draw_pixbuf(gc, @pixbuf.scale(imgw, imgh), 0, 0, 0, 0, imgw, imgh, Gdk::RGB::DITHER_NORMAL, 0, 0)
    debug "Drew image to screen"
  end

  def set_window_title(page_index, boxes)
    title = WINTITLE_PREFIX
    # no undo possible on first and last box of image
    notlast = (page_index+1<page_count || boxes.count > 1)
    title += "; backspace=undo" if !@previous_box.nil? && notlast
    title += " | #{File.basename(@img_path)}"
    title += " | page #{page_index+1}/#{page_count}"
    title += " | #{boxes.count} boxes left on this page"
    @window.title = title
  end

  # finds the next box which has not yet been processed. Falls back to
  # "process_next_file" if there are no more boxes for the curretnly
  # loaded image.
  def find_next_box
    debug "Looking for box..."
    @yaml.pages.each_with_index do |page, page_index|
      @page_index = page_index
      boxes = page.questions.map { |q| q.boxes }.flatten.select { |b| b.omr_result.nil? }
      set_window_title(page_index, boxes)
      # skip page if boxes empty
      next if boxes.empty?
      @previous_box = @box
      @box = boxes.first
      debug "Found box"
      draw_box_to_pixbuf
      return true
    end
    debug "Seem to have processed all boxes for this image"
    save_active_yaml
    # all boxes have been processed, see if there are more images
    return find_next_box if process_next_file
    # no new images, all boxes done
    false
  end

  def save_active_yaml
    return if @img_path.nil? || @yaml.nil?
    File.open(@img_path.gsub(/\.tif$/, "_ref.yaml"), 'w') do |out|
      YAML.dump(@yaml, out)
    end
    debug "Saved reference YAML for #{@img_path}"
  end

  # loads the next image and determines standard correctional values
  # (e.g. rotation) and also creates a new YAML file which may be
  # filled with the reference values.
  def process_next_file
    return false if @files.empty? && @images.empty?
    if @images.empty?
      @yaml_path, @images = @files.shift
    end
    @last_box = nil
    @img_path = @images.shift

    debug
    debug "Using #{@yaml_path}"
    @yaml = load_yaml_sheet(@yaml_path)
    debug "Now processing #{@img_path}"
    # load all pages of the image
    @ilist = Magick::ImageList.new(@img_path)
    if @ilist.count != page_count
      debug "The image has #{@ilist.count} pages, but the YAML says there"
      debug "should be #{page_count}. Skipping this sheet."
      return process_next_file
    end

    locate_corners
    if @cancelProcessing
      debug "OMR failed while trying to detect the rotation and offset."
      debug "Please have OMR create a debug print for this sheet; skipping"
      debug "it for now."
      return process_next_file
    end
    supplement_missing_corners
    debug "File loaded fine"

    true
  end

  # create the keyboard shortcuts
  def create_accels
    @window.signal_connect "key_press_event" do |widget, event|
      g = Gdk::Keyval
      k = Gdk::Keyval.to_lower(event.keyval)

      debug "Detected Keypress"
      debug "pressed: #{k}     valid: e=#{g::GDK_e} f=#{g::GDK_f} 8=#{g::GDK_v}"

      @box.omr_result = BOX_EMPTY if k == g::GDK_e    # most common
      @box.omr_result = BOX_CHECKED if k == g::GDK_f  # common
      @box.omr_result = BOX_BARELY if k == g::GDK_b   # uncommon
      @box.omr_result = BOX_OVERFULL if k == g::GDK_v # very uncommon
      if !@previous_box.nil? && k == g::GDK_BackSpace
        @previous_box.omr_result = nil
        @previous_box = nil
      end

      find_next_box
    end
  end

  # create the window
  def create_window
    @window = Gtk::Window.new
    @window.resizable = true
    @window.title = WINTITLE_PREFIX
    @window.signal_connect("delete_event") { Gtk.main_quit }
    @window.set_window_position Gtk::Window::POS_CENTER
    @window.maximize

    @area = Gtk::DrawingArea.new
    @area.add_events(Gdk::Event::BUTTON_PRESS_MASK)
    @area.add_events(Gdk::Event::BUTTON_RELEASE_MASK)
    @area.add_events(Gdk::Event::BUTTON_MOTION_MASK)
    @area.signal_connect("expose_event") { draw_image_to_screen }

    vbox = Gtk::VBox.new false
    vbox.pack_start @area, true, true, 1
    @window.add vbox

    create_accels
  end

  def initialize
    check_magick_version
    # assume image files are in 300 DPI
    @dpifix = 1.0

    @files = find_suitable_files
    @images = []

    create_window

    # load first image/box
    unless process_next_file
      puts "It appears all files have already been proccessed. Sorry."
      exit
      return
    end

    find_next_box
    @window.show_all

    while (Gtk.events_pending?)
      Gtk.main_iteration
    end
  end
end

Gtk.init
CreateGroundTruths.new
Gtk.main
