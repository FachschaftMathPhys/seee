#!/usr/bin/ruby

# PEST
# Praktisches Evaluations ScripT ( >> FormPro)
# (Practical Evaluation ScripT)
#
# Component: FIX
#
# Looks for "failed choices" in the data output by the OMR component
# and allows the user to manually correct this. Corrected data is written
# in place, so once you close the script, no undo will be possible unless
# you re-recognize the sheets.
#
# Known Bugs:
# When the preload is active, hitting enter seems to have no effect
#
# Usage: fix.rb   working_dir

require 'rubygems'
require 'RMagick'
require 'gtk2'
require 'tempfile'
require 'yaml'
require 'pp'

require 'helper.array.rb'
require 'helper.boxtools.rb'
require 'helper.constants.rb'
require 'helper.math.rb'


class PESTFix
    def initialize(win)
        puts Magick::Magick_version

        # global Variables
        @window = win
        @gdkrgb = Gdk::Pixbuf::ColorSpace::RGB
        @undoActions = []
        @files = []
        @dir = initGetWorkingDirectory
        @imgpath = ""
        @preloadMePlease = nil
        @noChoiceDrawWidth = 40
        # Call writeYAML if you change this!
        @currentImage = -1
        @yamlChanged = false
        
        parseDirectory
        initGui

        # Disabled for now as it confusingly hangs the app
        #@gtkParseDirThread = Gtk.timeout_add(30*1000) do
        #    Gtk.idle_add do
        #        parseDirectory
        #        false
        #    end
        #    true
        #end

        # Remove these more or less uninteresting "value set to"
        # messages after 5 seconds or so
        @gtkParseDirThread = Gtk.timeout_add(5*1000) do
            10.times { @statusbar.pop 1 }
            processEvents
            true
        end
    end

    # Extracts the working directory either from the command line argument
    # or displays a directory chooser dialog so the user can choose one.
    # If both of this fails the app will quit forcefully
    def initGetWorkingDirectory
        puts "Getting working directory"
        path = ARGV.shift
        #path = "09ss" # FIXME
        return path if path != nil && File.directory?(path)

        if path && File.exists?(path)
            @startUpImg = path.gsub(/\.tif$/, ".yaml")
            @startUpQuest = ARGV.shift
            puts "Loading predefined file ans question:"
            puts @startUpImg + " " + @startUpQuest.to_s
            return File.dirname(path)
        end        

        dialog = Gtk::FileChooserDialog.new("Select Working Directory",
                 nil,
                 Gtk::FileChooser::ACTION_SELECT_FOLDER,
                 nil,
                 [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                 [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
        dialog.set_window_position Gtk::Window::POS_CENTER


        if dialog.run == Gtk::Dialog::RESPONSE_ACCEPT
            f = dialog.filename
            dialog.destroy
            return f
        else
            # Kill the app
            dialog.destroy
            puts "Dieing in agony because you did not specify a directory"
            Process.exit
            return nil
        end
    end

    # Looks if the given file is already listed in @files
    def fileAlreadyParsed?(file)
        @files.assoc(file)
    end

    # Looks for YAML files in the working directory (@dir) and adds them
    # to the list. It will only add files which aren't indexed already
    def parseDirectory
        start_time = Time.now
        print "Parsing Directory... "
        newfiles = false
        # We can certainly skip the check on first load
        skipCheck = @files.empty?
        Dir.glob(@dir + "/*.yaml").each do |file|
            next if File.zero?(file)
            # Only add not already parsed files
            if !skipCheck; next if fileAlreadyParsed?(file); end
            # Arguments: filename, has been checked for errors
            @files << [file, false]
            newfiles = true
        end

        # Translate yaml path into index id
        if @startUpImg
            print "Found " + @startUpImg
            @startUpImg = @files.index([@startUpImg, false])
            puts " @ " + @startUpImg.to_s
        end
        
        puts "found new files! :D" if newfiles
        puts "but found nothing new :(" if !newfiles

        puts " (took: " + (Time.now-start_time).to_s + " s)"
        titleUpdate
        @find_fail.set_sensitive(true) if @find_fail != nil && newfiles
    end

    # Updates the window title
    def titleUpdate
        title = "PEST: Fix "
        count = "[" + (@currentImage+1).to_s + " / " + @files.size.to_s + "] "
        quest = "(Q: " + @currentQuestion.to_s + ") "
        @window.set_title title + count + quest + "    "+ @imgpath
    end

    # Contains definitions for all the toolbar buttons and sets them up
    def initToolbar
        # Setup all the buttons
        @undo = Gtk::ToolButton.new(Gtk::Stock::UNDO)
        @undo.set_tooltip_text "Undo the Last Change and Review Question (BACKSPACE) (CTRL + Z)"
        @undo.set_sensitive false
        @undo.signal_connect "clicked" do undo end

        @img_prev = Gtk::ToolButton.new(Gtk::Stock::GO_BACK)
        @img_prev.set_label "Prev. Sheet"
        @img_prev.set_tooltip_text "Load Previous Sheet (HOME)"
        @img_prev.signal_connect "clicked" do imagePrevNext(true) end
        
        @img_next = Gtk::ToolButton.new(Gtk::Stock::GO_FORWARD)
        @img_next.set_label "Next Sheet"
        @img_next.set_tooltip_text "Load Next Image (END)"
        @img_next.signal_connect "clicked" do imagePrevNext(false) end

        @quest_prev = Gtk::ToolButton.new(Gtk::Stock::GOTO_TOP)
        @quest_prev.set_label "Prev. Question"
        @quest_prev.set_tooltip_text "View the Previous Question (CTRL + UP ARROW) (PAGE UP)"
        @quest_prev.signal_connect "clicked" do questionPrevNext(true) end
        @quest_prev.set_sensitive(false)

        @quest_next = Gtk::ToolButton.new(Gtk::Stock::GOTO_BOTTOM)
        @quest_next.set_label "Next Question"
        @quest_next.set_tooltip_text "View the Next Question (CTRL + DOWN ARROW) (PAGE DOWN)"
        @quest_next.signal_connect "clicked" do questionPrevNext(false) end
        @quest_next.set_sensitive(false)
        
        @answr_prev = Gtk::ToolButton.new(Gtk::Stock::GOTO_FIRST)
        @answr_prev.set_label "Prev. Answer"
        @answr_prev.set_tooltip_text "Select the Previous/Lefthand Answer (LEFT/UP ARROW)"
        @answr_prev.signal_connect "clicked" do answerPrev end
        @answr_prev.set_sensitive(false)
        
        @answr_next = Gtk::ToolButton.new(Gtk::Stock::GOTO_LAST)
        @answr_next.set_label "Next Answer"
        @answr_next.set_tooltip_text "Select the Next/Righthand Answer (RIGHT/DOWN ARROW)"
        @answr_next.signal_connect "clicked" do answerNext end
        @answr_next.set_sensitive(false)
        
        @find_fail = Gtk::ToolButton.new(Gtk::Stock::FIND)
        @find_fail.set_label "Find Failed Question"
        @find_fail.set_tooltip_text "Finds an Improperly Answered Question (ENTER)"
        @find_fail.signal_connect "clicked" do questionFindFail end

        parse_again = Gtk::ToolButton.new(Gtk::Stock::REFRESH)
        parse_again.set_label "Find New Files"
        parse_again.set_tooltip_text "Parse Working Directory Again for New Files (CTRL + R)"
        parse_again.signal_connect "clicked" do parseDirectory end
        
        sql = Gtk::ToolButton.new(Gtk::Stock::SAVE_AS)
        sql.set_label "Export as SQL"
        sql.set_tooltip_text "Export the current datasheet as SQL file (CTRL + S)"
        sql.signal_connect "clicked" do exportAsSql end
        
        quit = Gtk::ToolButton.new(Gtk::Stock::QUIT)
        quit.set_tooltip_text "Exits the Application (CTRL + Q)"
        quit.signal_connect "clicked" do quitApp end

        @prog = Gtk::ProgressBar.new
        @prog.text = "If this moves, you stop!"
        @prog.set_pulse_step(0.025)
        pulse
        
        # Setup actual toolbar
        toolbar = Gtk::Toolbar.new  
        toolbar.set_toolbar_style Gtk::Toolbar::Style::BOTH
        toolbar.insert  0, @undo
        toolbar.insert  1, Gtk::SeparatorToolItem.new
        toolbar.insert  2, @img_prev
        toolbar.insert  3, @img_next
        toolbar.insert  4, Gtk::SeparatorToolItem.new
        toolbar.insert  5, @quest_prev
        toolbar.insert  6, @quest_next
        toolbar.insert  7, Gtk::SeparatorToolItem.new
        toolbar.insert  8, @answr_prev
        toolbar.insert  9, @answr_next
        toolbar.insert 10, Gtk::SeparatorToolItem.new
        toolbar.insert 11, @find_fail
        toolbar.insert 12, parse_again
        toolbar.insert 13, Gtk::SeparatorToolItem.new
        toolbar.insert 14, sql
        toolbar.insert 15, Gtk::SeparatorToolItem.new
        toolbar.insert 16, quit

        space = Gtk::ToolItem.new.add((Gtk::VBox.new false, 2))
        space.set_expand(true)
        toolbar.insert 17, space
        
        toolbar.insert 18, Gtk::ToolItem.new.add(@prog)

        toolbar
    end

    # Sets up all keyboard shortcuts globally
    def initAccelerators
        @window.signal_connect "key_press_event" do |widget, event|
            isCtrl = Gdk::Window::ModifierType::CONTROL_MASK == event.state
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
            if(isCtrl && k == g::GDK_z) || k == g::GDK_BackSpace then undo end

            # IMAGES PREV/NEXT
            if k == g::GDK_Home then imagePrevNext(true) end
            if k == g::GDK_End  then imagePrevNext(false) end

            # QUESTIONS UP/DOWN
            if(isCtrl && k == g::GDK_Up)   || k == g::GDK_Page_Up   then questionPrevNext(true) end
            if(isCtrl && k == g::GDK_Down) || k == g::GDK_Page_Down then questionPrevNext(false) end
            
            # ANSWERS
            if event.keyval == Gdk::Keyval::GDK_Left  || h == 47 then answerPrev end
            if event.keyval == Gdk::Keyval::GDK_Right || h == 51 then answerNext end

            # Go 5 answers down or up (especially useful for selecting tutors)
            if event.keyval == Gdk::Keyval::GDK_Up   || h == 34 then answerPrev(5) end
            if event.keyval == Gdk::Keyval::GDK_Down || h == 48 then answerNext(5) end

            # FAILED QUESTION
            if(k == g::GDK_3270_Enter || k == g::GDK_ISO_Enter) then questionFindFail end
            if(k == g::GDK_KP_Enter   || k == g::GDK_Return)   then questionFindFail end

            # PARSE DIR AGAIN
            if isCtrl && k == g::GDK_r then parseDirectory end

            # Export as SQL
            if isCtrl && k == g::GDK_s then exportAsSql end

            # Mark as Failed
            if isCtrl && k == g::GDK_f
                undoCommit
                @group['value'] = @group['failchoice']
                @yamlChanged = true
                @statusbar.push 1, "Setting value to " + @group['failchoice'].to_s + " (marking as failed)"
                imageUpdate
                answerButtonCheck
            end
            
            # QUIT
            if isCtrl && k == g::GDK_q then quitApp end

            @window.signal_emit_stop('key_press_event') 
        end
    end

    # Exports current data set as SQL
    # Doesn't force the user to solve all failed answers, but does a
    # lookup so the user may notice there's something not quite right.
    def exportAsSql
        questionFindFail

        dialog = Gtk::FileChooserDialog.new("Select Output SQL File",
                 nil,
                 Gtk::FileChooser::ACTION_SAVE,
                 nil,
                 [Gtk::Stock::CANCEL, Gtk::Dialog::RESPONSE_CANCEL],
                 [Gtk::Stock::OPEN, Gtk::Dialog::RESPONSE_ACCEPT])
        dialog.set_window_position Gtk::Window::POS_CENTER
        dialog.set_do_overwrite_confirmation true
        dialog.set_filename "output.sql"

        if dialog.run != Gtk::Dialog::RESPONSE_ACCEPT
            dialog.destroy
            return
        end
        f = dialog.filename.gsub(/(?=\s)/, "\\")
        dialog.destroy
        @statusbar.push 6, "Saving to " + f + " (have a look at the console if you want feedback. Otherwise just wait a bit)"

        system("ruby yaml2sql.rb " + @dir.gsub(/(?=\s)/, "\\") + " " + f + " overwrite &")
    end

    # Sets up all elements that allow the user to interact with and dis-
    # play them
    def initGui
        # Set Window Title Defaults and so on
        titleUpdate
        @window.signal_connect "destroy" do quitApp end
    
        # Center us for non-tiling WMs
        @window.set_window_position Gtk::Window::POS_CENTER
    
        # Keyboard Shortcuts
        initAccelerators

        # Setup GUI elements in order of appearance
        toolbar = initToolbar
        
        @statusbar = Gtk::Statusbar.new
        @statusbar.push 0, "Select Answer: arrow keys  #  Find next failed-question: Enter  #  Other shortcuts: See tooltips  #  Nerd shortcuts: see source"
        
        @area = Gtk::DrawingArea.new
        @area.signal_connect "expose_event" do imageDraw end

        help = "Quick Help: "
        help << "You can use this tool to correct questions that couldn't "
        help << "be determined automatically. Select what the user meant "
        help << "by using the ARROW KEYS and load the next question by "
        help << "hitting ENTER. You can undo using BACKSPACE. The "
        help << "selected answer is marked in green. DO NOT DECIDE FOR "
        help << "THE USER! If in doubt, select the left-most box to mark "
        help << "the question as unanswered."
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

        # Select at least some image
        #imagePrevNext(false)
        if @startUpImg
            jumpTo(@startUpImg, @startUpQuest)
            @startUpImg = nil
        else
            questionFindFail(false)
        end
    end

    # Jumps to given image and question and optionally sets the question's
    # value to the given answer.
    def jumpTo(image, question, answer = nil)
        undoEnd
        puts "Jumping to: " + image.to_s + " / " + question
        writeYAML
        @currentImage = image
        @currentQuestion = question
        sheetLoad

        # Find correct group
        @doc['page'].allChildren.each do |g|
            next if g['dbfield'] != @currentQuestion
            @group = g
            break
        end

        @group['value'] = answer if answer != nil
        #sheetLoad
        findPageForQuestion
        questionButtonCheck
        answerButtonCheck
        imageButtonCheck
        imageUpdate
        titleUpdate
        undoStart
    end

    # Undoes the last change made
    def undo
        return if @undoActions.empty?
        undo = @undoActions.pop
        @undo.set_sensitive false if @undoActions.empty?
        # Reset the checked state so findFailed finds this again
        @files[undo[0]][1] = false
        @yamlChanged = true      
        jumpTo(undo[0], undo[1], undo[2])
        @find_fail.set_sensitive(true)
        @statusbar.push 4, "Undid last change"
    end

    # This should be called whenever a new question is displayed. It saves
    # the given values into a temporary variable so they may be retrieved
    # if the user chooses to change the answer
    def undoStart
        #puts "Saving current values into temp undo buffer"
        return if !@group
        @undoStartState = [@currentImage, @currentQuestion, @group['value']]
    end

    # This puts the data into the real undo-stack so that it may be un-
    # done. The data needs to be gathered with undoStart beforehand
    def undoCommit
        @undoActions << @undoStartState if @undoStartState != nil
        @undoStartState = nil
        @undo.set_sensitive !@undoActions.empty?
    end

    # This checks if the latest entry in the undo buffer it actually worth
    # saving and removes it if not. E.g. if the user changes an answer and
    # manually corrects it afterwards, no real change has been carried out
    # and therefore may be removed.
    def undoEnd
        return # Deactivated for now
        a = @undoActions.last
        return if a.nil? || a[0] != @currentImage || a[1] != @currentQuestion
        # The value changed, so keep it in the undo list
        return if a[2] != @group['value']
        # else remove it
        @undoActions.pop
        @undo.set_sensitive !@undoActions.empty?
    end

    # Checks if the question buttons need to be en/disabled and does so
    def questionButtonCheck
        if !@doc || !@currentImage || !@currentQuestion || !@group
            @quest_prev.set_sensitive(false)
            @quest_next.set_sensitive(false)
            return
        end
        groups = @doc['page'].allChildren
        i = groups.index(@group)
        
        @quest_next.set_sensitive(i < groups.size-1)
        @quest_prev.set_sensitive(i > 0)

        titleUpdate
    end
    
    # Checks if the answer buttons need to be en/disabled and does so
    def answerButtonCheck
        if !@doc || !@currentImage || !@currentQuestion || !@group
            @answr_prev.set_sensitive(false)
            @answr_next.set_sensitive(false)
            return
        end

        if @group['value'] == @group['failchoice']
            @answr_prev.set_sensitive(true)
            @answr_next.set_sensitive(true)
            return
        end
        
        nochoice = @group['value'] == @group['nochoice']
                #|| @group['value'] ==     @group['failchoice']
        
        # Find currently selected answer
        if !nochoice
            cur = nil
            @group['boxes'].each do |b|
                next if @group['value'] != b['choice']
                # We've found the currently selected answer
                cur = b
                break
            end
        end
        
        p = !nochoice
        n = nochoice || (cur != nil && @group['boxes'].next(cur) != nil)
    
        @answr_prev.set_sensitive(p)
        @answr_next.set_sensitive(n)
    end

    # Does the various update operations after an answer has changed
    def answerChanged
        @yamlChanged = true
        @statusbar.push 1, "Setting value to " + @group['value'].to_s
        imageUpdate
        answerButtonCheck
    end

    # Selects the (current + amount)th answer and updates the image. If
    # already at the last answer, nothing will happen
    def answerNext(amount = 1)
        return if !@answr_next.sensitive?
        undoCommit
        found = false
        # If the current answer is either failed or nochoice, we need to select
        # the first real answer
        isBadAnsw = @group['value'] == @group['nochoice'] \
                || (@group['failchoice'] != nil && @group['value'] == @group['failchoice'])
        amount -= 1 if isBadAnsw
        @group['boxes'].each do |b|
            # If the boxes don't have a choice attribute, it's probably
            # a question that doesn't have different answers (i.e. a
            # comment field that's non rectangular). If so, choose the
            # choice attribute of the group and stop searching
            # Choice because we want to select the next answer
            if !b['choice']
                @group['value'] = @group['choice'] || 1
                answerChanged
                break
            end
            
            next if @group['value'] != b['choice'] && !found && !isBadAnsw
            found = true
            amount -= 1
            # Instead of selecting nothing when the "amount" to go is larger
            # than the available answers, select the last one
            next if amount >= 0 && @group['boxes'].next(b) != nil
            @group['value'] = b['choice']
            answerChanged
            return
        end
    end

    # Selects the (current - amount)th answer and updates the image. If
    # already at the first answer, it will switch to "noChoice" when
    # available. Otherwise, nothing will happen.
    def answerPrev(amount = 1)
        return if !@answr_prev.sensitive?
        undoCommit
        found = false
        
        @group['boxes'].reverse_each do |b|
            #puts "Group1: "+b['choice'].to_s
            # If the boxes don't have a choice attribute, it's probably
            # a question that doesn't have different answers (i.e. a
            # comment field that's non rectangular). If so, choose the
            # nochoice attribute of the group and stop searching.
            # Nochoice because we want to select the previous answer
            if !b['choice']                
                @group['value'] = @group['nochoice'] || 0
                break
            end
            
            next if @group['value'] != b['choice'] && !found
            found = true
            amount -= 1
            # Unlike answerNext, we don't check if the previous element
            # is nil because we want to exit the loop with no action so
            # we can easily select the "no choice" option
            next if amount >= 0
            @group['value'] = b['choice']
            answerChanged
            return
        end

        # We're already at the first, so select "nochoice"
        @group['value'] = @group['nochoice'] || 0
        answerChanged
    end

    # Finds the previous question for the current one, works across pages
    # and en/disables quest_next/prev buttons accordingly
    def questionPrevNext(isPrev)
        return if !@quest_next.sensitive? && !isPrev
        return if !@quest_prev.sensitive? && isPrev
        # Save undo before loading
        undoEnd

        # FIXME
        a = @doc['page'].allChildren
        a.each do |e|
            next if e['dbfield'] != @currentQuestion
            if isPrev
                new = a.previous(e)
            else
                new = a.next(e)
            end
            
            break if !new
            @currentQuestion = new['dbfield']
            @group = new
            break
        end
        findPageForQuestion
        questionButtonCheck
        answerButtonCheck
        imageUpdate
        undoStart
    end

    # Finds the page for the current question
    def findPageForQuestion
        @doc['page'].each_index { |i| @currentPage = i if @doc['page'][i].include?(@group) }
    end

    # Loads the first question of the current sheet and en/disbales the
    # quest_next/prev buttons accordingly
    def questionFirst
        undoEnd
        @currentPage = 0
        @group =  @doc['page'][0][1] # Selects first group
        @currentQuestion = @group['dbfield']
        questionButtonCheck
        answerButtonCheck
        undoStart
    end

    # Looks at all loaded @files and searches them for failed choices.
    # Selects the first failed question it finds. Pass true to look for
    # new files in the working directory if all loaded files are depleted
    def questionFindFail(reparseDirectory = true, isPreload = false)
        return if !@find_fail.sensitive?
        @statusbar.push 99, "### PLEASE WAIT ### LOOKING FOR FAILED QUESTION ###" if !isPreload
        @cancelFindFail = false
        puts "Looking for wrongly answered question"
        # Deactivate while searching
        @find_fail.set_sensitive(false)
        undoEnd

        writeYAML if !isPreload

        @files.each do |f|            
            next if f[1] || (isPreload && @imgpath ==f[0])
            isPreload ? processEvents : pulse
            if @cancelFindFail
                @statusbar.pop 99
                return
            end
            doc = YAML::load(File.new(f[0]))
            if !doc
                puts "WARNING: yaml file cannot be read or is broken: " + f[0]
                puts "Skipping to next file"
                next
            end
            doc['page'].allChildren.each do |g|
                next if g['value'] != g['failchoice']
                next if g['failchoice'] == nil
                curImg = @files.index(f)
                curQue = g['dbfield']
                @find_fail.set_sensitive(true)
                if !isPreload
                    jumpTo(curImg, curQue)
                    questionFindFailPreload
                end
                @statusbar.pop 99                    
                return curImg
            end
            f[1] = true
        end
        @statusbar.pop 99        

        # This is basically a convenient function that automatically looks
        # for new YAML files. Makes correcting while still parsing much
        # easier
        if reparseDirectory
            parseDirectory
            return questionFindFail(false)
        end
        
        # ok, all files seem to have passed
        @find_fail.set_sensitive(false)
        undoStart
        @statusbar.push 2, "No more failed questions found! (You may want to reload the directory for changes though)"
        # Load at least some image if none has been displayed so far
        imagePrevNext(false) if !@doc
        return nil
    end

    # Finds the next failed question without jumping to it, instead pre-
    # loads this image
    def questionFindFailPreload        
        @gtkThreadFindFail = Gtk.idle_add do
            @preloadMePlease = questionFindFail(false, true)
            sheetPreload
        end
    end

    # Small helper function that avoids stalling the GUI when doing
    # work intensive stuff on the main thread
    def processEvents
        while (Gtk.events_pending?)
            Gtk.main_iteration
        end
    end

    # Pluse the progress bar and process events so the change is visible
    # to the user. Note that this will kick off any Gtk.add_idle pro-
    # cesses.
    def pulse
        @prog.pulse
        processEvents
    end

    # Stops the find fail thread that may run in the background (i.e.
    # the user selected another image while searching)
    def stopFindFail
        Gtk.idle_remove(@gtkThreadFindFail) if @gtkThreadFindFail
        @cancelFindFail = true
        @find_fail.set_sensitive(true)
    end

    # Checks if the image buttons need to be en/disabled and does so
    def imageButtonCheck
        @img_prev.set_sensitive(@currentImage > 0)
        @img_next.set_sensitive(@currentImage < (@files.size-1))
    end

    # Small helper function that enables the prev/next buttons depending
    # on the current position, updates the window title and loads the
    # new image from disk
    def imagePrevNext(isPrev)
        return if !@img_next.sensitive? && !isPrev
        return if !@img_prev.sensitive? && isPrev
        @starttime= Time.now
        stopFindFail
        writeYAML
        oldImage = @currentImage
        if isPrev
            @currentImage-=1 if @currentImage > 0
            @preloadMePlease = @currentImage - 1
        else
            @currentImage+=1 if @currentImage < (@files.length-1)
            @preloadMePlease = @currentImage + 1
        end
        
        Gtk.idle_add { sheetPreload } 

        # Nothing changed, so we're already at the first/last image
        return if oldImage == @currentImage
        
        imageButtonCheck

        @imgpath = @files.length > @currentImage ? @files[@currentImage][0] : ""
        
        sheetLoad
        questionFirst
        imageUpdate
        titleUpdate
    end

    # Writes the changes to the YAML file if required. It uses the undo
    # buffer to determine if the current YAML document has changed
    def writeYAML
        return if !@yamlChanged
        a = @undoActions.last
        return if a.nil? || a[0] != @currentImage
        s = Time.now
        # Do this in a background thread, it goes from 0.10s to 0.20s
        # down to ~0.01s
        @yamlSaveThread = Thread.new do
            fout = File.open(@files[@currentImage][0], "w")
            fout.puts YAML::dump(@doc)
            fout.close
        end
        @yamlChanged = false
    end

    # Loads an image and its YAML file from disk. This only needs to
    # be called everytime the image changes (i.e. not for question and
    # answer changes). (followup: imageUpdate)
    def sheetLoad
        puts "=" * 20
        # No change, so don't bother
        return if @currentDisplayedImage == @currentImage
        start_time = Time.now
        
        @currentDisplayedImage = @currentImage
        f = @files[@currentImage]
        @imgpath = f[0]

        # Check for preload
        if @currentImage == @preloadID && @preloadIsDone
            # We don't need to destroy @orig here since it is swapped
            # with @preloadImage which gets destroyed later on
            @orig, @preloadImage = @preloadImage, @orig
            @doc = @preloadDoc
            @yamlChanged = false
            print "Pre-"
        else
            @orig.each { |x| x.destroy! } if @orig != nil
            # Load new IMG            
            dir = File.dirname(f[0])
            file = File.basename(f[0], ".yaml")
            img = dir + "/" + file + ".tif"

            @doc = YAML::load(File.new(f[0]))
            if !@doc
                puts "ERROR: yaml file cannot be read or is broken: " + f[0]
            end
            @yamlChanged = false
            
            if File.exists?(img)
                @orig = Magick::ImageList.new(img)
            else
                # This is a small tweak that at least doesn't crash the
                # application. It provides no info for the user what
                # went wrong, but that shouldn't happen.
                puts "ERROR: Image File not found: " + img
                @orig = Magick::ImageList.new
                @doc['page'].size.times do
                    @orig << Magick::Image.new(2480, 3507) {
                        self.background_color = 'grey'
                    }
                end
            end
            
            
        end

        puts "Loading IMG+YAML " + f[0] + " (took: " + (Time.now-start_time).to_s + " s)"
    end

    # Loads the sheet given by @preloadMePlease into memory if possible
    # The function is executed on the same thread as the caller, so avoid
    # calling it when doing other processing. Try the following:
    # <code>Gtk.idle_add { sheetPreload }</code>
    def sheetPreload
        # Don't preload the current or preloaded sheet
        return if @currentImage == @preloadMePlease  || @preloadID == @preloadMePlease || !@preloadMePlease

        # Mark the cache as invalid
        @preloadIsDone = false
        
        # Don't preload non-existing sheets
        return if @preloadMePlease <= 0 || @preloadMePlease > (@files.length-1)

        start_time = Time.now
        @preloadID = @preloadMePlease         
        f = @files[@preloadMePlease]

        @preloadImage.each { |x| x.destroy! } if @preloadImage != nil
        
        dir = File.dirname(f[0])
        file = File.basename(f[0], ".yaml")
        img = dir + "/" + file + ".tif"
        
        @preloadImage = Magick::ImageList.new(img)
        @preloadDoc = YAML::load(File.new(f[0]))
        
        @preloadIsDone = true
        puts "Preloading: " + f[0] + " (took: " + (Time.now-start_time).to_s + " s)"        
    end

    # This does most of the work related to generating the image. It
    # finds a suitable cutout and draws the boxes over it. The result
    # is saved to @pixbuf and the DrawingArea gets invalidated so the
    # changes show up (followup: imageDraw)
    def imageUpdate
        return if !@group || !@orig || !@currentPage
        start_time = Time.now
        print "Updating on screen image"

        x, y, width, height = calculateBounds(@group['boxes'], @group, @noChoiceDrawWidth)

        draw = Magick::Draw.new

        draw.font_weight = 100
        draw.pointsize = 20           

        # Draws the "no choice" checkbox
        draw.fill("white")
        draw.stroke("black")
        draw.rectangle(0, 0, @noChoiceDrawWidth, @noChoiceDrawWidth)    
        if @group['value'] == @group['nochoice']
            draw.fill("green")
            draw.stroke("green")
        else
            draw.fill("red")
            draw.stroke("red")
        end
        draw.fill_opacity(0.4)
        draw.rectangle(1, 1, @noChoiceDrawWidth, @noChoiceDrawWidth)

        # Draw the colored boxes
        @group['boxes'].each do |b|
            w, h = getBoxDimension(b, @group)
            # The former is for "normal" question where a different box
            # means a different answer. The latter is for when the whole
            # group can either be on or off but consists of several
            # boxes. E.g. a comment field that's not rectangular
            if @group['value'] == b['choice'] || (@group['value'] == @group['choice'] && @group['choice'])
                draw.fill("green")
                draw.stroke("green")
            else
                draw.fill("red")
                draw.stroke("red")
            end
            draw.fill_opacity(0.4)

            bx = b['x']
            by = b['y']
            bw = b['width']
            bh = b['height']
            
            draw.rectangle(bx-x, by-y, bx-x+w, by-y+h)
        end

        imgid = Math::min(@orig.length-1, @currentPage)

        # Create a new copy that we can waste
        img = @orig[imgid].crop(x, y, width, height)
        
        # Apply boxes
        #threadDrawImage.join
        draw.draw(img)

        # Hack! Hack! Writing it to disk and reading it again is still
        # faster than an in-memory way. Partly because Gdk's import
        # functions suck and partly due to RMagick's to_blob being very
        # slow
        temp = Tempfile.new("image")
        begin
            # Writing TIFs is fastest, so obviously use TIF. Takes
            # ~0.08s which is about three times faster
            img.write("tif:"+ temp.path)    
            @pixbuf = Gdk::Pixbuf.new(temp.path)
        rescue
            # However some of these are broken for no apparent reason
            # Work around this and save it as a JPG (was 2nd fastest)
            # Put altogether it takes ~0.18s when this occurs and is
            # as fast as an optimized in-memory path, so our loss isn't
            # too bad
            puts "BORKEN! BORKEN! ImageMagick/RMagick wrote a corrupted TIF again"
            img.write("jpg:"+ temp.path)    
            @pixbuf = Gdk::Pixbuf.new(temp.path)
        end
        
        # This was the old method. Without the thumbail stuff it took
        # ~0.27s, reducing the size speeded it up to ~0.18s for each
        # load. It's still too slow and it's a noticeable delay for the
        # user
        #img.thumbnail!(0.5)
        #blob = img.to_blob{self.depth=8; self.format="RGB"}
        #@pixbuf = Gdk::Pixbuf.new(blob, @gdkrgb, false, 8, 
        #                          img.columns, img.rows, img.columns*3)
        
        puts " (took: " + (Time.now-start_time).to_s + " s)"

        # Invalidate area if possible. This may not be the case when the
        # app starts up, but imageDraw will be called automatically any-
        # way, so we don't need to bother at this point
        return if @area == nil || @area.window == nil
        @area.queue_draw_area(0, 0, @area.window.size[0], @area.window.size[1])
    end

    # Draws the image stored in @pixbuf to the screen. Resizes the image
    # if required while maintaining the aspect ratio. Called everytime
    # the draw area was partially hidden (e.g. by tooltips) or when
    # the actual image changed
    def imageDraw
        return if @pixbuf == nil
        
        #start_time = Time.now
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
        @quickHelp.set_size_request maxw-8, -1
        @area.window.draw_pixbuf(gc, @pixbuf.scale(imgw, imgh), 0, 0, 0, 0, imgw, imgh, Gdk::RGB::DITHER_NORMAL, 0, 0)
        #puts "Drawing image to screen (took: " + (Time.now-start_time).to_s + " s)"
    end

    # Saves the changed YAML and quits the app gracefully
    def quitApp
        writeYAML
        Gtk.timeout_remove(@gtkParseDirThread) if @gtkParseDirThread
        stopFindFail
        @yamlSaveThread.join if @yamlSaveThread
        # This may assert in case there's a background thread running,
        # but for now I don't care
        Gtk.main_quit
        #begin Process.exit; rescue; end
    end
end

Gtk.init
window = Gtk::Window.new
fix = PESTFix.new(window)
Gtk.main