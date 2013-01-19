#!/usr/bin/env ruby
# encoding: utf-8

# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: OMR (Optical Mark Recognition)
#
# Parses a set of files or a given directory and saves the results for
# each image/sheet into the given directory. Results are the corrected
# x/y values for all elements given in the input-sheet (rotation, off-
# set) and the answers (choice attributes for each
# group/question). Outputs images for each fill out free text field if
# specified.
#
# Call omr2.rb without arguments for list of possible/required arguments
#
# This is version 2 which assumes the 'corners' option is enabled.

cdir = File.dirname(__FILE__)

require 'base64'
require 'rubygems'
require 'optparse'
require 'yaml'
require 'pp'
require 'fileutils'
require 'tempfile'
require "unicode_utils"

require cdir + '/helper.misc.rb' # also loads rmagick

require cdir + '/helper.boxtools.rb'
require cdir + '/helper.database.rb'
require cdir + '/helper.drawing.rb'
require cdir + '/helper.constants.rb'
require cdir + '/helper.image.rb'

require cdir + '/../web/app/lib/AbstractForm.rb'
require cdir + '/helper.AbstractFormExtended.rb'
require cdir + '/../web/app/lib/RandomUtils.rb'

# Profiler. Uncomment code at the end of this file, too.
#~ require 'ruby-prof'
#~ RubyProf.measure_mode = RubyProf::MEMORY
#~ RubyProf.measure_mode = RubyProf::ALLOCATIONS
#~ RubyProf.start


class PESTOmr < PESTDatabaseTools
  include PESTDrawingTools
  include PESTImageTools

  # Tries to locate a square box exactly that has been roughly located
  # using the position given by TeX and after applying offset+rotation.
  # Returns x, y coordinates that may be nil and also modifies the box
  # coordinates themselves (unless the box isn't found)
  def search_square_box(img_id, box)
    # TWEAK HERE
    if box.width.nil?
      box.width, box.height = 40, 40
      # TeX stores the box’s coordinates near its bottom right corner.
      # This translation is static and thus different to the one introduced
      # by imperfect scanning. Positive values move the box left/top.
      moveleft, movetop = 45, 47
    else
      # if the last box is a textbox, adjust some values so the textbox
      # can be checked. For now, only checked/unchecked is supported.
      moveleft, movetop = -10, 67
      box.height = 40
    end

    # Original position as given by TeX
    draw_transparent_box(img_id, box.tl, box.br, "yellow")
    # correct values to point to the box’s top left corner and print it
    box.x -= moveleft; box.y -= movetop
    # still need to address scanning skew
    tl = correct(img_id, [box.x, box.y])
    box.x, box.y = tl.x, tl.y
    draw_transparent_box(img_id, box.tl, box.br, "cyan", "", true)

    # Find the pre-printed box
    # search left → right
    x = search(img_id, [box.tl.x-6, box.tl.y-10],
          [box.br.x - box.width/3*2, box.br.y+10], :right, 30, true)
    # search bottom → top
    y = search(img_id, [box.tl.x-4, box.tl.y+box.height-6],
          [box.br.x+4, box.tl.y+box.height+9], :up, 40, true)
    y -= box.height unless y.nil?

    # note if we had to search again. If we do, it may be the case that
    # the whole form is misaligned.
    had_to_fix = { :horiz => false, :vert => false }

    # If any coordinate couldn't be found, try again further away. Only
    # searches the newly added area.
    if x.nil?
      x = search(img_id, [box.tl.x-15, box.tl.y-10],
            [box.tl.x-6, box.br.y+10], :right, 30)
      had_to_fix[:horiz] = true
    end
    # in case of y-direction, the line that divides the questions would
    # be detected. Search top down instead. Since bottom up failed, we
    # can be pretty sure the initial box was placed too high, therefore
    # we don’t need to add anything to the y-variable.
    if y.nil?
      y = search(img_id, [box.tl.x-4, box.tl.y],
            [box.br.x+4, box.br.y - box.height/3*2], :down, 40)
      had_to_fix[:vert] = true
    end

    box.x = x unless x.nil?
    box.y = y unless y.nil?

    draw_text(img_id, [x-15,y+20], "black", box.choice) unless [x,y].any_nil?

    return x, y, had_to_fix
  end

  # Finds and stores the black percentage for all boxes for the given
  # question in box.bp. Returns an array of box coordinates which
  # indicates which areas were being searched. Automatically runs more
  # thorough searches if no checkmarks are found.
  def process_square_boxes_blackness(img_id, question)
    # TWEAK HERE
    # thickness of the stroke
    stroke_width = 4
    # in certain cases the space around the printed box is searched.
    # _small describes the additional interval that should be excluded
    # around the box in pixels. Including the box in the black pixels
    # result makes it impossible to get good results. So don't set
    # this too low.
    # _large describes the area around the box to search.
    # In other words: the annulus with maximum norm and radii:
    # r = box/2 + _small  R = box/2 + _large
    around_small = 2
    around_large = 8

    debug_box = []

    fixes = { :horiz => 0, :vert => 0 }
    retried = false
    question.boxes.each_with_index do |box, i|
      x, y, had_to_fix = search_square_box(img_id, box)
      fixes[:horiz] += 1 if had_to_fix[:horiz]
      fixes[:vert] += 1 if had_to_fix[:vert]
      # Looks like the box doesn't exist. Assume it's empty.
      if x.nil? || y.nil?
        if !retried
          retried = true
          @auto_correction_vert -= 8
        end
        @soft_error += 1
        debug "Couldn't find box for page=#{img_id} box=#{box.choice}"+\
              " db_column=#{question.db_column} in #{@currentFile}"
        debug "Assuming there is no box and no choice was made."
        debug
        box.bp = 0
        next
      end
      retried = false

      # inside the box. Take one further pixel from the width of the box
      # because the results (omr-test) show that in many cases the boxes
      # have wider strokes than they should, at least when scanned.
      tl = [x+stroke_width+1, y+stroke_width]
      br = [x+box.width-stroke_width-1, y+box.height-stroke_width]
      box.bp = black_percentage(img_id, tl.x, tl.y, br.x-tl.x, br.y-tl.y)
      debug_box[i] = [tl, br]
    end

    # If many boxes were not found on the initial try for one question
    # then that’s a strong hint that the whole form is misaligned --
    # or at least it became misaligned due to imperfect printing and/or
    # scanning. In that case adjust a little so the next boxes my be
    # found on first try. The values are applied in helper.image.rb
    # correct/translate.
    h_fix_ratio = fixes[:horiz].to_f/question.boxes.size.to_f
    @auto_correction_horiz -= 3 if h_fix_ratio >= 0.65

    v_fix_ratio = fixes[:vert].to_f/question.boxes.size.to_f
    @auto_correction_vert += 3 if v_fix_ratio >= 0.65


    # see if there is anything inside the boxes. If yes, assume the user
    # knows how a checkbox works.
    return debug_box unless question.boxes.all? { |x| x.is_empty? }

    # okay, so all checkboxes are empty. Look outside the checkbox to
    # see if the user only has an awkward way to check the boxes (e.g.
    # circling them)
    question.boxes.each_with_index do |box, i|
      ow = box.width+2*around_large
      oh = box.height+2*around_large
      outer = black_pixels(img_id, box.x-around_large,
                box.y-around_large, ow, oh)

      # this includes the pre-printed box as well, so it may be
      # subtracted from the large box above
      iw = box.width+2*around_small
      ih = box.height+2*around_small
      inner = black_pixels(img_id, box.x-around_small,
                box.y-around_small, iw , ih)

      # add outer and existing black percentage
      box.bp = (box.bp + 100.0*(outer-inner).to_f/(ow*oh-iw*ih).to_f)/2.0

      debug_box[i] = [[box.x-around_large, box.y-around_large],
          [box.x+box.width+around_large, box.y+box.height+around_large]]
    end

    debug_box
  end

  # evaluates a single- or multiple choice question with square check-
  # boxes. Automatically corrects the boxes' position and computes the
  # black percentage and which boxes are checked and which are not. All
  # results are stored in the box themselves, but it also returns an
  # integer for single choice questions with the 'choice' attribute of
  # the selected box. Returns ANSW_FAIL if user intervention is required
  # and ANSW_NONE if no checkbox was selected. For multiple choice an
  # array with the choice attributes of the checked boxes is returned.
  # This array may be empty.
  def process_square_boxes(img_id, question)
    # calculate blackness for each box
    debug_box = process_square_boxes_blackness(img_id, question)

    # find all properly checked boxes
    checked = question.boxes.select { |x| x.is_checked? }

    # don't do fancy stuff for multiple choice questions
    is_multi = question.db_column.is_a? Array
    result = if is_multi
      checked.collect { |box| box.choice }
    else # single choice question
      case checked.size
        # only one checkbox remains, so go for it
        when 1 then checked.first.choice
        when 0 then # no checkboxes. We're officially desperate now. Let’s
                    # try again with lower standards.
          barely = question.boxes.select { |x| x.is_barely_checked? }
          case barely.size
            when 1 then barely.first.choice # one barely checked, take it
            # no barely checked either. If there are any overfull ones,
            # ask the user; otherwise the question really wasn’t answered
            when 0 then ((question.boxes.any? { |x| x.is_overfull? }) ? ANSW_FAIL : ANSW_NONE)
            else    ANSW_FAIL # at least two boxes are barely checked, ask user
          end
        else ANSW_FAIL # at least two boxes are checked, ask user
      end # case
    end # else

    # print debug boxes
    question.boxes.each_with_index do |box, i|
      # this happens if a box couldn't be found. So don't debug it.
      next if debug_box[i].nil?

      color = "magenta" # should never be used
      color = "orange" if box.is_empty?
      color = "#5BF1B2" if box.is_barely_checked?
      color = "green" if box.is_checked? # i.e. a nice checkmark
      color = "red" if box.is_overfull?

      draw_transparent_box(img_id, debug_box[i][0], debug_box[i][1],
        color, box.bp.round_to(1), true)
      draw_text(img_id, [box.x-20,box.y+40], "black", "X") if box.is_checked?
    end
    # print question's db_column left of question
    q = question.db_column
    draw_text(img_id, [10, debug_box.compact.first[0].y+10], "black", \
      (q.is_a?(Array) ? q.join(", ") : q))

    result
  end

  # Assumes a whole page for commentary. Crops a margin to remove any black
  # bars and then trims to any text if there.
  def process_whole_page(img_id, group)
    i = @ilist[img_id]
    # Crop margins to remove black bars that appear due to rotated sheets
    c = @corners[img_id]
    x = ((c[:tr].x + c[:br].x)/2.0 - (c[:tl].x + c[:bl].x)/2.0).to_i
    y = ((c[:bl].y + c[:br].y)/2.0 - (c[:tl].y + c[:tr].y)/2.0).to_i
    # safety margin so that the corners are not included
    s = 2*30*dpifix
    c = i.crop(Magick::CenterGravity, x-s, y-s).trim(true)

    # region is too small, assume it is empty
    return 0 if c.rows*c.columns < 500*dpifix

    c = c.resize(0.4)

    step = 20*dpifix
    thres = 100

    # Find left border
    left = 0
    while left < c.columns
      break if black_pixels_img(c, left, 0, step, c.rows) > thres
      left += step
    end
    return 0 if left >= c.columns

    # Find right border
    right = c.columns
    while right > 0
      break if black_pixels_img(c, right-step, 0, step, c.rows) > thres
      right -= step
    end
    return 0 if right < 0

    # Find top border
    top = 0
    while top < c.rows
      break if black_pixels_img(c, 0, top, c.columns, step) > thres
      top += step
    end
    return 0 if top >= c.rows

    # Find bottom border
    bottom = c.rows
    while bottom > 0
      break if black_pixels_img(c, 0, bottom-step, c.columns, step) > thres
      bottom -= step
    end
    return 0 if bottom < 0

    c.crop!(left-50, top-50, right-left+2*50, bottom-top+2*50)
    c.trim!(true)

    # check again for size after cropping. Drop if too small.
    return 0 if c.rows*c.columns < 500*dpifix

    filename = @path + "/" + File.basename(@currentFile, ".tif")
    filename << "_" + group.save_as + ".jpg"
    debug "  Saving Comment Image: " + filename if @verbose
    c.write filename
    c.destroy!

    return 1
  end

  # detects if a text box contains enough text and reports the result
  # (0 = no text, 1 = has text). It will automatically extract the
  # portion of the scanned sheet with the text and save it as .jpg.
  def process_text_box(img_id, question)
    # TWEAK HERE
    limit = 1000 * dpifix
    # the x,y coordinate is made before the box, so we need to account
    # for the box border. It marks the top left corner.
    addtox, addtoy = 15, 15
    # the width,height are made inside the box, so we don’t have to
    # account for the box border. Note that width/height is actually a
    # coordinate until we make it relative below
    addtow, addtoh = 15, 1

    # init that no black pixels have been found so far
    bp = 0

    # only take first box into account, multi-rectangle comments are not
    # supported
    b = question.boxes.first
    # apply correction values and make width/height relative. Note that
    # TeX’s coordinates are from the lower left corner, but we use the
    # top left corner. This is usually corrected when loading the YAML
    # file, but since width/height are not supposed to be coordinates we
    # have to do it by hand. Grep this: WIDTH_HEIGHT_AS_COORDINATE
    b.x += addtox; b.y += addtoy; b.width += addtow - b.x
    b.height = PAGE_HEIGHT*dpifix - b.height - b.y + addtoh
    # in a perfect scan, the coordinates now mark the inside of the box
    draw_dot(img_id, correct(img_id, b.top_left), "red")
    draw_dot(img_id, correct(img_id, b.top_right), "red")
    draw_dot(img_id, correct(img_id, b.bottom_left), "red")
    draw_dot(img_id, correct(img_id, b.bottom_right), "red")

    # split into smaller chunks, so we can skip the rest of the comment
    # box once enough black pixels have been found
    boxes = splitBoxes(b, 150, 100)

    boxes.each do |box|
      # correct skew
      tl = correct(img_id, box.tl)
      br = correct(img_id, box.br)
      # update box values
      box.x, box.y = tl.x, tl.y
      box.width, box.height =  br.x-tl.x, br.y-(tl.y)
      # search
      bp += black_pixels(img_id, box.x, box.y, box.width, box.height)
      color = bp > limit ? "green" : "red"
      draw_transparent_box(img_id, tl, br, color, bp, true)
      break if bp > limit
    end

    return 0 if bp <= limit

    # Save the comment as extra file if possible/required
    save_text_image(img_id, question.save_as, boxes)
    return 1
  end

  # Saves a given area (in form of a boxes array) for the current image.
  def save_text_image(img_id, save_as, boxes, expand = 30)
    return if save_as.nil? || save_as.empty?
    debug("    Saving Comment Image: #{save_as}", "save_image") if @verbose
    filename = @path + "/" + File.basename(@currentFile, ".tif")
    filename << "_" + save_as + ".jpg"
    x, y, w, h = calculateBounds(boxes)
    newy = [y - expand, 0].max
    newh = [h + expand + (y-newy), PAGE_HEIGHT].min
    img = @ilist[img_id].crop(0, newy, PAGE_WIDTH, newh, true).minify

    # write out file
    img.write filename
    img.destroy!

    if @debug
      draw_text(img_id, [x,y], "green", "Saved as: #{filename}")
      draw_transparent_box(img_id, [x,y], [x+w,y+h], "#DBFFD8", "", true)
    end
    debug("    Saved Comment Image", "save_image") if @verbose
  end

  # Looks at each group listed in the yaml file and calls the appro-
  # priate functions to parse it. This is determined by looking at the
  # "type" attribute as specified in the YAML file. Results are saved
  # directly into the loaded sheet.
  def process_questions
    debug("  Recognizing Image", "recog_img") if @verbose

    0.upto(page_count - 1) do |i|
      if @doc.pages[i].questions.nil?
        debug "WARNING: Page does not contain any questions."
        debug "Are you sure there's a correct 'questions:' marker in the"
        debug "YAML file?"
        next
      end

      @auto_correction_horiz = 0
      @auto_correction_vert = 0

      @doc.pages[i].questions.each do |g|
        @currentQuestion = g.db_column
        case g.type
          when "square" then
            g.value = process_square_boxes(i, g)
          when "text" then
            g.value = process_text_box(i, g)
          when "text_wholepage" then
            g.value = process_whole_page(i, g)
          else
            debug "    Unsupported type: " + g.type.to_s
        end
      end
    end
    debug("  Recognized Image", "recog_img") if @verbose
  end

  # Does all of the overhead work required to be able to recognize an
  # image. More or less, it glues together all other functions and at
  # the end the result will be stored in the database
  def process_file(file)
    @cancelProcessing = false
    if !File.exists?(file) || File.zero?(file)
      debug "WARNING: File not found: " + file
      return
    end

    @currentFile = file

    start_time = Time.now
    debug("  Loading Image: #{file}", "loading_image") if @verbose

    # Load image and yaml sheet.
    @ilist = Magick::ImageList.new(file)
    @doc = load_yaml_sheet(@omrsheet)
    @draw = {}

    if @debug
      # Create @draw element for each page for debugging
      0.upto(page_count-1) do |i|
        create_drawable(i)
        draw_boilerplate(i, Dir.pwd, @omrsheet, file)
      end
    end

    debug("  Loaded Image", "loading_image") if @verbose

    # do the hard work
    @soft_error = 0
    locate_corners
    supplement_missing_corners unless @cancelProcessing
    process_questions unless @cancelProcessing
    # if there are many soft errors, like not found text boxes, mark the
    # sheet bizarr. Likely the base sheet with position information does
    # not fit.
    @cancelProcessing = true if @soft_error >= 10


    # Draw debugging image with thresholds, selected fields, etc.
    if @debug
      debug("  Applying debug drawing", "debug_print") if @verbose
      0.upto(page_count-1) do |i|
        begin
          # reduce black to light gray so transparent debug output may
          # have better visibility
          @ilist[i] = @ilist[i].level_colors("#ccc", "white")
          # draw a visible line to keep the pages apart
          draw_line(i, [0,0], [0, @ilist[i].rows], "black") if i > 0
          @draw[i].draw(@ilist[i])
        rescue; end
      end
      debug("  Applied drawing", "debug_print") if @verbose

      dbgFlnm = gen_new_filename(file, "_DEBUG.jpg")
      debug("  Saving Image: #{dbgFlnm}", "saving_image") if @verbose
      img = @ilist.append(false)
      img.write(dbgFlnm) { self.quality = 90 }
      img.destroy!
      debug("  Saved Image", "saving_image") if @verbose
    end

    # remove reference to image so GC may kick in
    @ilist.each { |i| i.destroy! }
    @ilist = nil

    if @cancelProcessing
      debug "  Something went wrong while recognizing this sheet."
      return if @test_mode || @debug # don't move the sheet in test/debug
      debug "  Moving #{File.basename(file)} to bizarre"
      dir = File.join(File.dirname(file).gsub(/\/[^\/]+$/, ""), "bizarre/")
      FileUtils.makedirs(dir)
      FileUtils.move(file, File.join(dir, File.basename(file)))
      `rm "#{file.gsub(/\.tif$/, "*")}"` # remove comments and similar
      return
    end

    # Output generated data
    store_results(@doc, file)
  end

  # stores the results from the given doc into the database and also
  # writes out the YAML file if in debug mode
  def store_results(yaml, filename)
    keys = Array.new
    vals = Array.new

    # Get barcode
    keys << "barcode"
    vals << find_barcode_from_path(filename).to_s

    keys << "path"
    vals << filename

    keys << "abstract_form"
    vals << Base64.encode64(Marshal.dump(yaml))

    yaml.questions.each do |q|
      next if q.type == "text" || q.type == "text_wholepage"
      next if q.db_column.nil?

      if q.multi?
        q.boxes.each_with_index do |box,i|
          vals << (q.value && q.value.include?(box.choice) ? box.choice : 0).to_s
          keys << q.db_column[i]
        end
      else
        vals << (q.value.nil? ? 0 : Integer(q.value)).to_s
        keys << q.db_column
      end
    end

    q = "INSERT INTO #{yaml.db_table} ("
    q << keys.join(", ")
    q << ") VALUES ("
    # inserts right amount of question marks for easy
    # escaping
    q << (["?"]*(vals.size)).join(", ")
    q << ")"

    # only create YAMLs in debug and test mode
    if @debug || @test_mode
      fout = File.open(gen_new_filename(filename), "w")
      fout.puts YAML::dump(@doc)
      fout.close
    end

    # don't write to DB in test mode
    return if @test_mode
    begin
      RT.custom_query_no_result("DELETE FROM #{yaml.db_table} WHERE path = ?", [filename])
      RT.custom_query_no_result(q, vals)
    rescue DBI::DatabaseError => e
      debug "Failed to insert #{File.basename(filename)} into database."
      debug q
      debug "Error code: #{e.err}"
      debug "Error message: #{e.errstr}"
      debug "Error SQLSTATE: #{e.state}"
      debug
      debug "Aborting due to database error."
      # still raise, so its printed into PEST_ERROR_LOG
      raise
    rescue
      debug "Failed to insert #{File.basename(filename)} into database."
      debug "Aborting due to random error."
      # still raise, so its printed into PEST_ERROR_LOG
      raise
    end
  end

  # Helper function that determines where the parsed data should go
  def gen_new_filename(file, ending = ".yaml")
    return @path + "/" + File.basename(file, ".tif") + ending
  end

  # Checks for existing files and issues a warning if so. Returns a
  # list of non-existing files
  def remove_processed_images_from(files)
    # don’t do anything in test mode because there is no database access
    # and we want to test all files anyway
    return files if @test_mode

    debug "Checking for existing files" if @verbose

    oldsize = files.size
    RT.custom_query("SELECT path FROM #{db_table}").each do |row|
      files.delete(row["path"])
    end
    if oldsize != files.size
      debug "Skipping #{oldsize-files.size} already processed files."
    end

    files
  end

  # Iterates a list of filenames and parses each. Checks for existing
  # files if told so.
  def process_file_list(files)
    overall_time = Time.now
    skipped_files = 0

    debug "Processing first of #{files.length} files"

    files.each_with_index do |file, i|
      # Processes the file and prints processing time
      file_time = Time.now

      percentage = (i.to_f/files.length*100.0).to_i
      debug("Processing File #{i}/#{files.length} (#{percentage}%)", "whole_file") if @verbose

      begin
        process_file(file)
      rescue => e
        debug "FAILED: #{file}"
        message = "\n\n\n\nFAILED: #{file}\n#{e.message}\n#{e.backtrace.join("\n")}"
        File.open("PEST_OMR_ERROR.log", 'a+') do |errlog|
          errlog.write(message)
        end
        debug "="*20
        debug "OMR is EXITING! Fix this issue before attemping again! (See PEST_OMR_ERROR.log)"
        debug message if @verbose
        exit 1
      end

      if @verbose
        debug("Processed file", "whole_file")
      end

      # Calculates and prints time remaining
      processed_files = i+1 - skipped_files
      if processed_files > 0
        time_per_file = (Time.now-overall_time)/processed_files.to_f
        remaining_files = (files.length-processed_files)
        timeleft = time_per_file*remaining_files/60.0
        if @verbose
          debug "Time remaining: #{timeleft.as_time}"
        else
          percentage = ((i+1).to_f/files.length*100.0).to_i
          debug "#{timeleft.as_time} left (#{percentage}%, #{i+1}/#{files.length})"
        end
      end
    end

    # Print some nice stats
    debug
    debug
    t = Time.now-overall_time
    f = files.length - skipped_files
    debug "Total Time: #{(t/60).as_time} (for #{f} files)"
    debug "(that's #{((t/f)/60).as_time} per file)"
  end

  # Parses the given OMR sheet and extracts globally interesting data
  # and ensures the database table exists.
  def parse_omr_sheet
    return unless @db_table.nil?
    debug "Parsing OMR sheet…"

    if !File.exists?(@omrsheet)
      debug "Couldn't find given OMR sheet (" + @omrsheet + ")"
      exit 6
    end
    # can’t use load_yaml_sheet here because it needs more dependencies
    # that are not yet available
    doc = YAML::load(File.read(@omrsheet))

    @page_count = doc.pages.count
    @db_table = doc.db_table
    if @db_table.nil?
      debug "ERROR: OMR Sheet #{@omrsheet} doesn’t define in which table the results should be stored. Add a db_table value to the form in the YAML root."
      debug "Exiting."
      exit 2
    end

    create_table_if_required(doc) unless @test_mode
  end

  # returns the db_table that is used for the currently processed form
  def db_table
    parse_omr_sheet if @db_table.nil?
    @db_table
  end

  # returns the amount of pages that are defined in the currently
  # processed form AND that are available in the loaded image
  def page_count
    parse_omr_sheet if @page_count.nil?
    [@page_count, @ilist.size].compact.min
  end

  # Reads the commandline arguments and does some basic sanity checking
  # Returns non-empty list of files to be processed.
  def parse_commandline
    # Define useful default values
    @omrsheet,  @path  = nil, nil
    @overwrite, @debug = false, false
    @test_mode = false
    @cores     = 1
    @dpifix    = nil

    # Option Parser
    begin
      opt = OptionParser.new do |opts|
        opts.banner = "Usage: omr2.rb --omrsheet omrsheet.yaml --path workingdir [options] [file1 file2 …]"
        opts.separator("")
        opts.separator("REQUIRED ARGUMENTS:")
        opts.on("-s", "--omrsheet OMRSHEET", "Path to the OMR Sheet that should be used to parse the sheets") { |sheet| @omrsheet = sheet }

        opts.on("-p", "--path WORKINGDIR", "Path to the working directory where all the output will be saved.", "All image paths are relative to this.") { |path| @path = path.chomp("/") }

        opts.separator("")
        opts.separator("OPTIONAL ARGUMENTS:")
        opts.on("-o", "--overwrite", "Specify if you want to output files in the working directory to be overwritten") { @overwrite = true }

        opts.on("-c", "--cores CORES", Integer, "Number of cores to use (=processes to start)", "This spawns a new ruby process for each core, so if you want to stop processing you need to kill each process. If there are no other ruby instances running, type this command: killall ruby") { |c| @cores = c }

        opts.on("-q", "--dpi DPI", Float, "The DPI the sheets have been scanned with.", "This value is autodetected ONCE. This means you cannot mix sheets with different DPI values") { |dpi| @dpifix = dpi/300.0 }

        opts.on("-v", "--verbose", "Print more output (sets cores=1)") { @verbose = true }

        opts.on("-d", "--debug", "Specify if you want debug output as well.", "Will write a JPG file for each processed sheet to the working directory; marked with black percentage values, thresholds and selected fields.", "Be aware, that this makes processing about four times slower.", "Automatically activates debug database (may be overwritten by test mode)") { @debug = true }

        opts.on("-t", "--testmode", "Sets useful values for running tests.", "Disables database access and stops files from being moved to bizarre/.") { @test_mode = true }

        opts.on( '-h', '--help', 'Display this screen' ) { puts opts; exit }
      end
      opt.parse!
    rescue Exception => e
      puts "Parsing arguments didn't work. Please check your commandline is correct."
      puts "Error given:"
      puts e
      puts
      opt.parse(["-h"]) if !@path || !@omrsheet
      exit
    end

    # For some reason, the option parser doesn't halt the app over
    # missing mandatory arguments, so we do have to check manually
    opt.parse(["-h"]) if !@path || !@omrsheet

    if !File.directory?(@path)
      debug "Given directory #{@path} does not exist, skipping."
      exit
    end

    # if debug is activated, use SQLite database instead.
    set_debug_database if @debug

    # Verbose and multicore processing don't really work together,
    # the output is just too ugly.
    if @verbose && @cores > 1
      @cores = 1
      debug "WARNING: Disabled multicore processing because verbose is enabled."
    end

    files = []
    # If no list of files is given, look at the given working
    # directory.
    if ARGV.empty?
      files = Dir.glob(@path + "/*.tif")
      if files.empty?
        debug "No tif images found in #{@path}. Exiting."
        exit
      end
    else
      ARGV.each { |f| files << @path + "/" + f }
    end

    # remove files that have already been processed, unless the user
    # wants them to be overwritten
    files = remove_processed_images_from(files) unless @overwrite
    if files.empty?
      debug "All files have been processed already. Exiting."
      exit
    end

    files
  end

  # Splits the given file and reports the status of each sub-process.
  def delegate_work(files)
    splitFiles = files.chunk(@cores)

    cmd = " -p " + @path.gsub(/(?=\s)/, "\\")
    cmd << (" -s " + @omrsheet.gsub(/(?=\s)/, "\\"))
    cmd << (@debug     ? " -d " : " ")
    cmd << (@test_mode ? " -t " : " ")
    cmd << (@overwrite ? " -o " : " ")
    # let the subprocess determine DPI on their own when loading the
    # first file, unless it has been manually set.
    cmd << " --dpi #{dpifix*300.0}" unless @dpifix.nil?

    tmpfiles, threads, exit_codes = [], [], []

    splitFiles.each_with_index do |f, corecount|
      next if f.empty?

      cachedir = Seee::Config.file_paths[:cache_tmp_dir]
      FileUtils.makedirs(cachedir)
      tmp = Tempfile.new("pest-omr-status-#{corecount}--", cachedir).path
      tmpfiles << tmp

      list = ""
      f.each { |x| list << " " + File.basename(x).gsub(/(?=\s)/, "\\") }
      threads << Thread.new(tmp) do |log_path|
        `ruby #{File.dirname(__FILE__)}/omr2.rb #{cmd} #{list} > #{log_path}`
        exit_codes[corecount] = $?.exitstatus
      end
    end

    STDOUT.sync = false
    begin
      print_progress(tmpfiles)
    rescue SystemExit, Interrupt
      debug
      debug "Halting processing threads..."
      threads.each { |x| x.kill }
      debug "All threads stopped. Exiting."
      STDOUT.flush
      exit
    end
    exit_codes
  end

  # prints the progress that is printed into the given tmpfiles.
  # Returns once all tmpfiles are deleted
  def print_progress(tmpfiles)
    last_length = 0
    while Thread.list.length > 1
      tmpf = tmpfiles.dup
      tmpf.reject! { |x| !File.exists?(x) }
      print "\r" + " "*last_length + "\r"
      last_length = 0
      tmpf.each_with_index do |x, i|
        dat = `tail -n 1 #{x} 2> /dev/null`.strip
        dat = dat.ljust([dat.length+7, 50].max) if i < tmpf.size - 1
        print dat
        last_length += dat.length
      end

      STDOUT.flush
      sleep 1
    end
    puts
    debug "Done."
  end

  # Class Constructor
  def initialize
    # required for multi core processing. Otherwise the data will
    # not be written to the tempfiles before the sub-process exits.
    STDOUT.sync = true
    files = parse_commandline
    check_magick_version

    # Let other ruby instances do the hard work for multi core...
    if @cores > 1
      exit_codes = delegate_work(files)
      if exit_codes.sum > 0
        debug "Some of the work processes failed for some reason."
        debug "Consult PEST_OMR_ERROR.log for more information."
        debug "Exitcodes are: #{exit_codes.join(", ")}"
      end
    # or do it in this instance for single core processing
    else
      # All set? Ready, steady, parse!
      parse_omr_sheet

      # Iterates over the given filenames and recognizes them
      begin
        process_file_list(files)
      rescue Interrupt, SystemExit => e
        ex = e.status if e && e.is_a?(SystemExit)
        debug
        debug "Caught exit or interrupt signal. Exiting. #{ex}"
        exit 3
      end
    end
  end
end

PESTOmr.new()

#~ result = RubyProf.stop
#~ printer = RubyProf::FlatPrinter.new(result)
#~ printer.print(STDOUT, 0)
