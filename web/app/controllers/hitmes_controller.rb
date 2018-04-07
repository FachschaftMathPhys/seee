# encoding: utf-8

class HitmesController < ApplicationController
  def overview
    render :action => "overview"
  end

  def active_users
    render :partial => "active_users"
  end

  def assign_work
    if (cookies["username"] || "").gsub(/[^a-z0-9_\s-]/i, "").blank?
      flash[:error] = "No username set, cannot continue."
      redirect_to :action => "overview"
      return
    end

    skip = cookies[:skip_course].to_i

    # randomize type of work first, then try to get a random chunk for
    # the selected type. If there isn’t one, try the next type until
    # work is found or all options are depleted. This setup avoids
    # finding /all/ available chunks while still being kinda-random.
    @workon = nil
    is_final_checkable = false
    (0..3).to_a.shuffle.each do |x|
      case x
        when 0 then @workon = Hitme.get_workable_comment_by_step(0, skip)
        when 1 then @workon = Hitme.get_workable_comment_by_step(1, skip)
        when 2 then @workon = Hitme.get_combinable(skip)
        when 3 then
          # required because final checkables and course combines are
          # the same class
          @workon = Hitme.get_final_checkable(skip)
          is_final_checkable = !@workon.nil?
      end
      break unless @workon.nil?
    end

    @workon.freeze

    if @workon.nil?
      flash[:notice] = "Currently no available tasks. Try again later."
      redirect_to :action => "overview"
    else
      # make collision detection happy
      hitmes_params[:controller] = @workon.class.to_s.pluralize.downcase
      hitmes_params[:id] = @workon.id

      @ident = precreate_session(@workon)

      case @workon.class.to_s
        when "Pic"  then render :action => "type_proofread"
        when "CPic" then render :action => "type_proofread"
        when "Tutor"  then render :action => "combine"
        when "Course" then
          render :action => is_final_checkable ? "final_check" : "combine"
        else raise "not implemented"
      end
    end
  end

  # handles updating text and step for comment typing and proofreading.
  # automatically redirects the user according to the action chosen.
  def save_comment
    x = case hitmes_params[:type]
      when "CPic" then CPic.find(hitmes_params[:id])
      when  "Pic" then Pic.find(hitmes_params[:id])
      else nil
    end

    if hitmes_params[:cancel] || x.nil?
      flash[:error] = "The comment image in question could not be found." if x.nil?
      redirect_to :action => "overview"

    elsif hitmes_params[:save_and_skip]
      x.text = hitmes_params[:text]
       # initialize step to 0, otherwise the validations might fail
      x.step ||= 0
      flash[:error] = "Your changes could not be saved. Please investigate." if not x.save
      redirect_to :action => "assign_work"

    elsif hitmes_params[:save_and_quit] || hitmes_params[:save_and_work]
      x.text = hitmes_params[:text]

      next_step = { nil => Hitme::PROOFREADING, Hitme::TYPING => Hitme::PROOFREADING, Hitme::PROOFREADING => Hitme::COMBINING }
      if next_step.keys.include?(x.step)
        x.step = next_step[x.step]
        x.step = Hitme::DONE if x.step == Hitme::COMBINING && x.text.blank?
      else
        flash[:warning] = "Could not advance step, there might have been a collision. You shouldn’t worry too much about it though."
      end

      if x.save
        flash[:notice] = "Changes have been saved."
      else
        flash[:error] = "Your changes could not be saved. Please investigate before continuing."
      end

      redirect_to :action => hitmes_params[:save_and_quit] ? "overview" : "assign_work"

    else
      flash[:error] = "Invalid action given. Your comment was not saved."
      redirect_to :action => "overview"
    end

    remove_session(x)
  end


  def save_combination
    x = case hitmes_params[:type]
      when "Course" then Course.find(hitmes_params[:id])
      when "Tutor"  then Tutor.find(hitmes_params[:id])
      else nil
    end

    if hitmes_params[:cancel] || x.nil?
      flash[:error] = "Could not find course/tutor with given ID." if x.nil?
      redirect_to :action => "overview"

    elsif hitmes_params[:save_and_skip]
      x.comment = hitmes_params[:text]
      flash[:error] = "Your combination/merge could not be saved. Please investigate." if not x.save
      redirect_to :action => "assign_work"

    elsif hitmes_params[:save_and_quit] || hitmes_params[:save_and_work]
      x.comment = hitmes_params[:text]

      if x.save
        flash[:notice] = "Changes have been saved."
        # advance all comments by one step
        pics = x.respond_to?("c_pics") ? x.c_pics : x.pics
        flash[:warning] = "Could not advance to the next step." unless pics.update_all(:step => Hitme::FINALCHECK)
      else
        flash[:error] = "Your changes could not be saved. Please investigate before continuing."
      end

      redirect_to :action => hitmes_params[:save_and_quit] ? "overview" : "assign_work"

    else
      flash[:error] = "Invalid action given. Your comment was not saved."
      redirect_to :action => "overview"
    end

    remove_session(x)
  end


  def save_final_check
    course = Course.find(hitmes_params[:id])
    errs = []
    step_warn = false

    errs << "Couldn’t find specified course. Saving failed." unless course
    if course
      course.comment = hitmes_params[:course]
      unless course.save
        errs << "Couldn’t save course."
      else
        step_warn = true unless course.c_pics.update_all(:step => Hitme::DONE)
      end
    end

    hitmes_params[:tutor].each do |tut_id, text|
      logger.info "Processing tutor=#{tut_id}"
      tutor = Tutor.find(tut_id)
      unless tutor
        errs << "Couldn’t find specified tutor. Saving failed."
        next
      end
      tutor.comment = text
      unless tutor.save
        errs << "Couldn’t save tutor #{tutor.abbr_name}."
      else
        step_warn = true unless tutor.pics.update_all(:step => Hitme::DONE)
      end
    end if hitmes_params[:tutor]

    remove_session(course)

    if errs.empty?
      flash[:notice] = "Save successful." unless hitmes_params[:save_and_skip]
      if hitmes_params[:save_and_skip] || hitmes_params[:save_and_work]
        redirect_to :action => "assign_work"
      else  # hitmes_params[:save_and_quit] and others
        redirect_to :action => "overview"
      end
    else
      flash[:error] = errs.join("<br />").html_safe
      redirect_to :action => "overview"
    end
  end


  def preview_text
    text = hitmes_params[:text]
    text = hitmes_params[:listify].to_s == "true" ? view_context.text_to_list(text) : text
    render :partial => "shared/preview", :locals => {
      :text => text,
      :disable_cache => true}
  end


  def cookie_test
    render :json => cookies[:testcookie] == "test value"
  end

  private
  def precreate_session(workon)
    # golf via http://stackoverflow.com/a/88341/1684530
    ident = (0...9).map{65.+(rand(26)).chr}.join.downcase

    x = Session.new(:cont => workon.class.to_s.pluralize.downcase, :viewed_id => workon.id)
    x.ident = ident
    x.agent = request.env['HTTP_USER_AGENT']
    x.ip = request.env['REMOTE_ADDR']
    x.username = (cookies["username"] || "").gsub(/[^a-z0-9_\s-]/i, "")[0..20]
    x.save
    ident
  end

  def remove_session(workon)
    return unless workon && hitmes_params[:ident]
    Session.unscoped.delete_all(
      :cont => workon.class.to_s.pluralize.downcase,
      :viewed_id => workon.id,
      :ident => hitmes_params[:ident]
    )
  end
  private
  def hitmes_params
    params.permit!
  end
end
