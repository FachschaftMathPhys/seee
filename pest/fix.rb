#!/usr/bin/env ruby
# encoding: utf-8

# PEST
# Praktisches Evaluations ScripT
# (Practical Evaluation ScripT)
#
# Component: FIX
#
# Looks for "failed choices" in the data output by the OMR component
# and allows the user to manually correct this. Corrected data is
# written into the database columns, but the ruby object stored in
# the abstract_form column is left untouched.
#
# If you start the script without parameters, it will connect to the
# database as set up in seee_config.rb. If you specify a working
# directory, it will go into debug mode and read an SQLite database
# file in the given directory.
#
# By default, all tables are loaded. You can specify a list of table
# names to limit to certain tables.
#
# Usage: fix.rb [table, [table, […]]] [/full/path/to/debug_directory]

# Some config options ##################################################
# this array contains all of the types that can currently be fixed
SUPPORTED_TYPES = ["square"]

# includes #############################################################
cdir = File.dirname(__FILE__)
require cdir + '/../web/config/ext_requirements.rb'
Bundler.require(:pest)

require File.join(cdir, 'helper.boxtools.rb')
require File.join(cdir, 'helper.database.rb')
require File.join(cdir, 'helper.constants.rb')
require File.join(cdir, 'helper.misc.rb')


require File.join(cdir, 'helper.AbstractFormExtended.rb')


class PESTFix < PESTDatabaseTools
  def initialize(win)
    # this array will hold all failed questions, even after they have
    # been corrected. It is an array of arrays, similar to a hash but
    # ordered. The first element of each contained array acts as an
    # identifier, the 2nd contains the actual question.
    @all_failed_questions = []

    # for performance reasons, we store the paths of all files that
    # have already been processed. This allows us to skip loading of
    # the abstract form each time.
    @all_processed_paths = []

    # used as status indicator
    @corrected = []

    # stores the identifiers of each question as they were changed in
    # the past
    @undo = []

    debug Magick::Magick_version

    if !ARGV.nil? && !ARGV.last.nil? && File.exist?(ARGV.last) && ARGV.last.start_with?("/")
      @path = ARGV.pop
      debug "Using debug path = #{@path}"
      set_debug_database
    end

    find_tables_to_process

    # global Variables
    @window = win
  #  @gdkrgb = GdkPixbuf::Pixbuf::ColorSpace::RGB
    @noChoiceDrawWidth = 40

    init_gui
  end

  # accessors for the current question and related data ################
  attr_accessor :current_question
  def current_question=(new_question)
    return if @current_question == new_question
    debug "Setting new question"
    @current_question = new_question
    @current_db_value = nil
    render_image # also force draws image to screen
    update_window_title_and_progressbar
    update_toolbar
    debug "Fill degrees: #{current_boxes.collect{|b| b.bp}.join(", ")}"
  end

  def current_boxes
    @current_question["question"].boxes
  end

  def current_path
    @current_question["path"]
  end

  def current_db_column
    @current_question["question"].db_column
  end

  # removes the identifier for the current question
  def current_ident
    "#{current_path}_#{current_db_column}"
  end

  # loads the value as stored in the DB for the current question
  def current_db_value
    return @current_db_value if @current_db_value
    debug "Loading current value from DB"
    table = @current_question["table"]
    x = RT.custom_query("SELECT #{current_db_column} FROM #{table} WHERE path = ?", [current_path], true)
    @current_db_value = x[current_db_column].to_i
  end

  # stores the given value for the current question in the DB and calls
  # all necessary screen-update function. Also prints what OMR thinks
  # about this checkbox (i.e. empty, checked, overfull)
  def current_db_value=(value)
    return if @current_db_value == value
    @current_db_value = value.to_i
    t1 = Thread.new do
      debug nil, "db_save"
      table = @current_question["table"]
      field = @current_question["question"].db_column
      RT.custom_query_no_result("UPDATE #{table} SET #{field} = ? WHERE path = ?",
                                                  [value, current_path])
      debug "Set DB value to #{value}", "db_save"

      box_stat = nil
      @current_question["question"].boxes.each do |b|
        if current_db_value == b.choice.to_i
          box_stat = "empty"
          box_stat = "checked" if b.is_checked?
          box_stat = "barely checked" if b.is_barely_checked?
          box_stat = "overfull" if b.is_overfull?
        end
      end
      box_stat = "OMR thinks this checkbox is #{box_stat}." if box_stat

      @statusbar.pop 1
      @statusbar.push 1, "Setting value to #{value}. #{box_stat}"
    end
    t2 = Thread.new { render_image }

    ci = current_ident
    # remove any occurences of this question in the undo buffer and
    # append it to the end. If it is present, it means the question
    # has been corrected before, so decrease count.
    @undo.delete(ci)
    @undo << ci

    # increase count for fixed questions
    if value >= 0
      @corrected << ci unless @corrected.include?(ci)
    else
      @corrected.delete(ci)
    end

    update_toolbar
    t1.join; t2.join
  end

  # data related utils #################################################

  # loads the value stored in the DB for the given question
  def db_value_for_question(q)
    col = q["question"].db_column
    RT.custom_query("SELECT #{col} FROM #{q["table"]} WHERE path = ?", [q["path"]], true)[col]
  end

  # Undo will first view the question without making any changes if it
  # is not the one currently shown. Once it is, it will set it to its
  # original value.
  def undo
    if current_ident == @undo.last
      # reset
      self.current_db_value = current_question["question"].value
      @undo.pop
      update_toolbar
    else
      old = @all_failed_questions.assoc(@undo.last)
      return unless old
      self.current_question = old[1]
    end
  end

  # Moves the current file to ../bizarre from its current location
  def mark_as_bizarre
    biz = File.join(File.dirname(current_path), "..", "bizarre")
    File.move(current_path, biz)
  end

  # Opens the currently shown sheet in an external viewer
  def open_in_viewer
    fork { exec "#{Seee::Config.application_paths[:pdf_viewer]} \"#{current_path}\"" }
  end

  # will go through all available databases and collect all failed
  # questions and add them to @all_failed_questions. It does not remove
  # existing entries in the variable.
  def find_all_failed_questions
    # loose checking to prevent the function twice at the same time
    return if @find_all_failed_questions
    @find_all_failed_questions = true
    new_questions = 0
    @tables.each do |t,f|
      q = "SELECT path, abstract_form, #{f.join(", ")} FROM #{t} WHERE #{f.join("=-1 OR ")}=-1"
      res = RT.custom_query(q)
      res.each do |q|
        # skip all files that have already been processed
        next if @all_processed_paths.include?(q["path"])
        @all_processed_paths << q["path"]
        form = Marshal.load(Base64.decode64(q["abstract_form"]))
        # use the database result to check if a question is failed.
        # AbstractForm is never changed, so already fixed questions need
        # to be excluded.
        form.questions.select { |qq| q[qq.db_column].to_i == -1 }.each do |qq|
          ident = "#{q["path"]}_#{qq.db_column}"
          # skip existing entries
          next unless @all_failed_questions.assoc(ident).nil?
          data = {}
          data["path"] = q["path"]
          data["table"] = t
          form.pages.each_with_index do |p,i|
            data["page"] = i if p.questions.include?(qq)
          end
          data["question"] = qq
          @all_failed_questions << [ident, data]
          new_questions += 1
        end
      end
    end
    debug "Found #{new_questions} new question(s)"
    @find_all_failed_questions = false
  end

  # Searches through @all_failed_questions and finds all questions that
  # have not yet been fixed
  def find_failed_question
    return unless @find_fail.sensitive?
    @statusbar.pop 1 # remove old "setting value to" messages

    # Deactivate while searching
    @find_fail.set_sensitive(false)

    @statusbar.push 99, "### LOOKING FOR FAILED QUESTION ###"
    debug "Looking for wrongly answered question"

    find_all_failed_questions
    @all_failed_questions.each do |q|
      # skip questions that are not failed anymore
      next unless db_value_for_question(q[1]).to_i == -1

      debug "Found failed question"
      self.current_question = q[1]
      @statusbar.pop 99
      @find_fail.set_sensitive(true)
      return q[1]
    end

    @find_fail.set_sensitive(true)
    @statusbar.pop 99
    @statusbar.push 3, "No more failed questions!"
    update_window_title_and_progressbar
    unless @all_done_popup_shown
      @all_done_popup_shown = true
      popup_info("You're done!", "All failed questions have been processed. Unless images are still processed in the background, you can exit this application.")
    end
    return nil
  end

  # Either takes the list of tables given via command line or simply
  # uses all available tables. It asserts that the tables appear fixable
  # and returns a hash in the format of table => ["list", "of", "columns"]
  # The array only contains columns that are questions in the matching
  # abstract form and only supported types are listed.
  def find_tables_to_process
    return @tables unless @tables.nil?
    temp = ARGV
    temp = list_available_tables if temp.nil? || temp.empty?
    @tables = {}
    temp.each do |t|
      t = t.scan(/[a-z0-9\-_]/i).join
      debug "Checking #{t}"
      # only add tables if they exist AND have an abstract_form column
      begin
        form = RT.custom_query("SELECT abstract_form FROM #{t}", [], true)
        form = Marshal.load(Base64.decode64(form["abstract_form"]))
        valid_fields = form.questions.collect do |q|
          SUPPORTED_TYPES.include?(q.type) ? q.db_column : nil
        end
        valid_fields.compact!
        # HACK HACK HACK! Remove after current eval. FIXME FIXME FIXME
        if valid_fields.include?("tutnum")
          valid_fields.delete("tutnum")
          valid_fields << "tutor_id"
        end

        @tables[t] = valid_fields.flatten unless valid_fields.empty?
      rescue => e
        debug "Table #{t} doesn't appear to be valid or doesn’t exist."
        debug "Error message: #{e.message}"
      end
    end
    @tables
  end

  # navigation related #################################################

  # tries to find the previous and next question. Returns array in the
  # form of [prev, next]. If one element doesn’t exist, it will be nil.
  def find_prev_next_question # FIXME
    a = @all_failed_questions
    # find the index of the current question
    index = a.index(a.assoc(current_ident))

    p = index == 0          ? nil : a[index - 1][1]
    n = index == a.size - 1 ? nil : a[index + 1][1]

    [p, n]
  end

  # selects the previous question
  def select_prev_question
    prev = find_prev_next_question[0]
    self.current_question = prev if prev
  end

  # selects the previous question
  def select_next_question
    nxt = find_prev_next_question[1]
    self.current_question = nxt if nxt
  end

  # Selects the (current + amount)th answer. If already at the last
  # answer, nothing will happen. If current answer is either failed or
  # nochoice, will choose nochoice and the first box respectively.
  def select_next_answer(amount = 1)
    if current_db_value <= 0
      # failed/no choice
      index = -1 + amount
    else # n-th box
      index = current_boxes.find_index { |b| b.choice.to_i == current_db_value } + amount
    end
    # don't go out of bounds
    new_index = Math.min(index, current_boxes.size - 1)
    self.current_db_value = current_boxes[new_index].choice
  end

  # selects the (current - amount)th answer. If failed, 1st box or no
  # choice is selected, no choice will be selected.
  def select_prev_answer(amount = 1)
    if current_db_value <= 0
      # failed/no choice → no choice
      self.current_db_value = 0
    else # n-th box
      index = current_boxes.find_index { |b| b.choice == current_db_value }
      # don't go out of bounds
      new_index = Math.max(index - amount, -1)
      if new_index >=0
        self.current_db_value = current_boxes[new_index].choice
      else
        # first box → nochoice
        self.current_db_value = 0
      end
    end
  end

  # gui related ########################################################

  # Contains definitions for all the toolbar buttons and sets them up
  def init_toolbar
    # Setup all the buttons
    @undo_btn = Gtk::ToolButton.new(Gtk::Stock::UNDO)
    @undo_btn.set_tooltip_text "Undo the Last Change and Review Question (BACKSPACE) (CTRL + Z)"
    @undo_btn.set_sensitive false
    @undo_btn.signal_connect "clicked" do undo end

    @quest_prev = Gtk::ToolButton.new(Gtk::Stock::GOTO_TOP)
    @quest_prev.set_label "Previous"
    @quest_prev.set_tooltip_text "View the Previous Question (CTRL + UP ARROW) (PAGE UP)"
    @quest_prev.signal_connect "clicked" do select_prev_question end
    @quest_prev.set_sensitive(false)

    @quest_next = Gtk::ToolButton.new(Gtk::Stock::GOTO_BOTTOM)
    @quest_next.set_label "Next"
    @quest_next.set_tooltip_text "View the Next Question (CTRL + DOWN ARROW) (PAGE DOWN)"
    @quest_next.signal_connect "clicked" do select_next_question end
    @quest_next.set_sensitive(false)

    @answr_prev = Gtk::ToolButton.new(Gtk::Stock::GOTO_FIRST)
    @answr_prev.set_label "Prev. Answer"
    @answr_prev.set_tooltip_text "Select the Previous/Lefthand Answer (LEFT/UP ARROW)"
    @answr_prev.signal_connect "clicked" do select_prev_answer end
    @answr_prev.set_sensitive(false)

    @answr_next = Gtk::ToolButton.new(Gtk::Stock::GOTO_LAST)
    @answr_next.set_label "Next Answer"
    @answr_next.set_tooltip_text "Select the Next/Righthand Answer (RIGHT/DOWN ARROW)"
    @answr_next.signal_connect "clicked" do select_next_answer end
    @answr_next.set_sensitive(false)

    @find_fail = Gtk::ToolButton.new(Gtk::Stock::FIND)
    @find_fail.set_label "Find Failed"
    @find_fail.set_tooltip_text "Finds an Improperly Answered Question (ENTER)"
    @find_fail.signal_connect "clicked" do find_failed_question end

    @mark_as_bizarre = Gtk::ToolButton.new(Gtk::Stock::NO)
    @mark_as_bizarre.set_label "Mark File Bizarr"
    @mark_as_bizarre.set_tooltip_text "Mark the current file as bizarre, i.e. if it's scanned incorrectly."
    @mark_as_bizarre.signal_connect "clicked" do mark_as_bizarre end

    @open_in_viewer = Gtk::ToolButton.new(Gtk::Stock::SELECT_ALL)
    @open_in_viewer.set_label "View File"
    @open_in_viewer.set_tooltip_text "Open the currently shown sheet in an external viewer."
    @open_in_viewer.signal_connect "clicked" do open_in_viewer end

    quit = Gtk::ToolButton.new(Gtk::Stock::QUIT)
    quit.set_tooltip_text "Exits the Application (CTRL + Q)"
    quit.signal_connect "clicked" do quit_application end

    @prog = Gtk::ProgressBar.new

    # Setup actual toolbar
    toolbar = Gtk::Toolbar.new
    toolbar.set_toolbar_style Gtk::Toolbar::Style::BOTH
    c = -1
    toolbar.insert((c+=1), @find_fail)
    toolbar.insert((c+=1), @undo_btn)
    toolbar.insert((c+=1), @open_in_viewer)
    toolbar.insert((c+=1), Gtk::SeparatorToolItem.new)
    toolbar.insert((c+=1), @quest_prev)
    toolbar.insert((c+=1), @quest_next)
    toolbar.insert((c+=1), @answr_prev)
    toolbar.insert((c+=1), @answr_next)
    toolbar.insert((c+=1), Gtk::SeparatorToolItem.new)
    toolbar.insert((c+=1), @mark_as_bizarre)
    toolbar.insert((c+=1), quit)

    space = Gtk::ToolItem.new.add(Gtk::VBox.new false, 2)
    space.set_expand(true)
    toolbar.insert((c+=1), space)

    toolbar.insert((c+=1), Gtk::ToolItem.new.add(@prog))

    toolbar
  end

  # Sets up all keyboard shortcuts globally
  def init_accelerators
    @window.signal_connect "key_press_event" do |widget, event|
      ctrl = Gdk::Window::ModifierType::CONTROL_MASK == event.state
      g = Gdk::Keyval
      k = Gdk::Keyval.to_lower(event.keyval)

      # Nerd Shortcuts
      # This is used to provide an alternative to the arrow keys for
      # selecting an answer. It allows correcting more easily because
      # you don't need to move your hand while hitting enter. Great
      # for when eating pizza (or watching porn). It's located at:
      # QWERTZ: üöä#
      # QWERTY: [;'\
      # NEO2DE: ßdy\
      h = event.hardware_keycode

      # UNDO
      undo if(ctrl && k == g::GDK_z) || k == g::GDK_BackSpace

      # QUESTIONS UP/DOWN
      select_prev_question if(ctrl && k == g::GDK_Up)   || k == g::GDK_Page_Up
      select_next_question if(ctrl && k == g::GDK_Down) || k == g::GDK_Page_Down

      # ANSWERS
      select_prev_answer if event.keyval == Gdk::Keyval::GDK_Left  || h == 47
      select_next_answer if event.keyval == Gdk::Keyval::GDK_Right || h == 51

      # Go 5 answers down or up (especially useful for selecting tutors)
      select_prev_answer(5) if event.keyval == Gdk::Keyval::GDK_Up   || h == 34
      select_next_answer(5) if event.keyval == Gdk::Keyval::GDK_Down || h == 48

      # FAILED QUESTION
      find_failed_question if(k == g::GDK_3270_Enter || k == g::GDK_ISO_Enter)
      find_failed_question if(k == g::GDK_KP_Enter   || k == g::GDK_Return)

      # QUIT
      quit_application if ctrl && k == g::GDK_q

      @window.signal_emit_stop('key_press_event')
    end
  end

  # Sets up all elements that allow the user to interact with and dis-
  # play them
  def init_gui
    # Set Window Title Defaults and so on
    update_window_title_and_progressbar
    @window.signal_connect "destroy" do quit_application end

    # Center us for non-tiling WMs
    @window.set_window_position Gtk::Window::POS_CENTER
    @window.set_default_size(500, 600)

    # Keyboard Shortcuts
    init_accelerators

    # Setup GUI elements in order of appearance
    toolbar = init_toolbar

    @statusbar = Gtk::Statusbar.new

    @area = Gtk::DrawingArea.new
    @area.signal_connect "expose_event" do draw_image_to_screen end

    help = "Quick Help:\n"
    help << "ARROW KEYS: select answer\n"
    help << "ENTER: next question\n"
    help << "TOP LEFT BOX: choose if result ambiguous (e.g. 2 checkmarks)\n"
    help << "BORDER COLORS: cyan = barely checked, blue = nice checkmark, purple = overfull"
    @quickHelp = Gtk::Label.new(help)
    @quickHelp.set_wrap true

    # Now lets put it all together
    vbox = Gtk::VBox.new false
    vbox.pack_start toolbar, false
    vbox.pack_start @area, true, true, 1
    vbox.pack_start @quickHelp, false, false, 2
    vbox.pack_start @statusbar, false
    @window.add vbox

    # All done. Let's display it.
    @window.show_all

    while (Gtk.events_pending?)
      Gtk.main_iteration
    end

    # try to find failed question
    find_failed_question
  end

  # Small helper function that avoids stalling the GUI when doing
  # work intensive stuff on the main thread
  def process_events
    while (Gtk.events_pending?)
      Gtk.main_iteration
    end
  end

  # Quits application gracefully
  def quit_application
    # This may assert in case there's a background thread running,
    # but for now I don't care
    Gtk.main_quit
  end

  # Updates the window title
  def update_window_title_and_progressbar
    all = @all_failed_questions.size

    # find index of current question, set to 0 if not found
    current = @all_failed_questions.index { |q| q[1] == current_question}
    current ||= -1
    current += 1

    corr = @corrected.size

    if @prog
      count = "Fixed: #{corr} / #{all}"
      if all == count || all == 0 && count == 0
        @prog.text = "All done!"
        @prog.fraction = 1
      else
        @prog.text = count
        @prog.fraction = corr.to_f / all.to_f
      end
    end

    title = []
    title << "PEST: Fix"
    title << "Viewing: #{current} / #{all}"
    title << count if count
    if current_question
      title << "Question: #{current_question["question"].db_column}"
      title << current_path
    end
    @window.set_title title.join(" | ")
  end

  def update_toolbar
    p = n = true
    p = n = false if current_question.nil?
    p = n = true if current_db_value == -1
    p = false if current_db_value == 0
    n = false if current_db_value == current_boxes.last.choice
    @answr_prev.sensitive = p
    @answr_next.sensitive = n

    p, n = find_prev_next_question
    @quest_prev.set_sensitive(p)
    @quest_next.set_sensitive(n)

    @undo_btn.set_sensitive(!@undo.empty?)
    @mark_as_bizarre.set_sensitive(!current_question.nil?)
    @open_in_viewer.set_sensitive(!current_question.nil?)
  end

  # popups a gtk message dialog with the given title and text
  def popup_info(title, text)
    dialog = Gtk::MessageDialog.new(
      @window,
      Gtk::Dialog::MODAL,
      Gtk::MessageDialog::INFO,
      Gtk::MessageDialog::BUTTONS_OK,
      text
    )
    dialog.title = title
    dialog.run
    dialog.destroy
  end

  # image handling #####################################################

  # Loads the image at given path into memory
  def load_image_from_disk(path)
    return true if @load_image_from_disk == path
    @load_image_from_disk = path
    debug "Loading image at #{path}", "loading_img"
    # Destroy old image
    unless @orig.nil?
      @orig.each { |x| x.destroy! }
    end
    # Load new IMG
    if File.exists?(path)
      @orig = Magick::ImageList.new(path)
      @dpifix = @orig[0].dpifix
    else
      # This is a small tweak that at least doesn't crash the
      # application. It provides no info for the user what
      # went wrong, but that shouldn't happen.
      debug "ERROR: Image File not found: " + path
      return false
    end
    debug "Loaded image", "loading_img"
    true
  end

  # This does most of the work related to generating the image. It
  # finds a suitable cutout and draws the boxes over it. The result
  # is saved to @pixbuf and the DrawingArea gets invalidated so the
  # changes show up (followup: draw_image_to_screen)
  def render_image
    return if current_question.nil?
    q = current_question["question"]
    debug nil, "render_image"

    return unless load_image_from_disk(current_path)
    x, y, width, height = calculateBounds(q.boxes, q, @noChoiceDrawWidth)

    imgid = Math::min(@orig.length-1, current_question["page"])
    # Create a new copy that we can waste
    img = @orig[imgid].crop(x, y, width, height)

    draw = Magick::Draw.new
    draw.stroke_width(2)
    draw.stroke_antialias(false)

    # Draws the "no choice" checkbox
    color = current_db_value == 0 ? "green" : "red"
    draw.fill(color)
    draw.stroke(color)
    draw.fill_opacity(0.4)
    draw.rectangle(1, 1, @noChoiceDrawWidth, @noChoiceDrawWidth)


    # Draw the colored boxes
    q.boxes.each do |b|
      border = color = current_db_value == b.choice.to_i ? "green":"red"
      border = "#0098FF" if b.is_checked? # true for normal and barely
      border = "cyan" if b.is_barely_checked?
      border = "#A200FF" if b.is_overfull?

      draw.fill(color)
      draw.stroke(border)
      draw.fill_opacity(0.4)
      w, h = getBoxDimension(b, q)
      draw.rectangle(b.x-x, b.y-y, b.x-x+w, b.y-y+h)
    end

    # apply drawings
    draw.draw(img)

    # Hack! Hack! Writing it to disk and reading it again is still
    # faster than an in-memory way. Partly because Gdk's import
    # functions suck and partly due to RMagick's to_blob being very
    # slow
    temp = Tempfile.new("image.jpg")
    img.write("jpg:"+ temp.path)
    @pixbuf = GdkPixbuf::Pixbuf.new(temp.path)

    debug "rendered image", "render_image"

    # Invalidate area if possible. This may not be the case when the
    # app starts up, but draw_image_to_screen will be called automatically any-
    # way, so we don't need to bother at this point
    return if @area == nil || @area.window == nil
    @area.queue_draw_area(0, 0, @area.window.size[0], @area.window.size[1])
  end

  # Draws the image stored in @pixbuf to the screen. Resizes the image
  # if required while maintaining the aspect ratio. Called everytime
  # the draw area was partially hidden (e.g. by tooltips) or when
  # the actual image changed
  def draw_image_to_screen
    return if @pixbuf == nil
    debug nil, "img2screen"
    gc = @window.style.fg_gc(@area.state)

    maxw = @area.window.size[0].to_f
    maxh = @area.window.size[1].to_f

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
    @quickHelp.set_size_request maxw-8, -1
    @area.window.draw_pixbuf(gc, @pixbuf.scale(imgw, imgh), 0, 0, 0, 0, imgw, imgh, Gdk::RGB::DITHER_NORMAL, 0, 0)
    debug "Drew image to screen", "img2screen"
  end
end

# application init #####################################################
Gtk.init
window = Gtk::Window.new
fix = PESTFix.new(window)
Gtk.main
