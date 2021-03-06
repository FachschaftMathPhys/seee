# encoding: utf-8

class CoursesController < ApplicationController
  # GET /courses
  # GET /courses.xml
  def index
    @curr_term ||= view_context.get_selected_terms
    if @curr_term.empty?
      flash[:error] = "Cannot list courses for current term, as there isn’t any current term. Please create a new one first."
      redirect_to :controller => "terms", :action => "index"
      return
    end
    # don’t allow URLs that have the search parameter without value
    if courses_params[:search] && courses_params[:search].empty?
      redirect_to :controller => "courses", :action => "index"
      return
    end

    cond = "term_id IN (?)"
    vals = view_context.get_selected_terms.map { |s| s.id }

    # filter by search term. Provide it as additional array, so the table
    # may hide entries instead of not showing them at all. This allows
    # javascript filtering, even if a query was submitted via HTTP.
    if courses_params[:search]
      @matches = Course.search(courses_params[:search], [:profs, :faculty], [cond], [vals], [:faculty_id, :title])

      # if a search was performed and there is exactly one result go to it
      # directly instead of listing it
      if @matches.size == 1
        redirect_to(@matches.first)
        return
      end
    end

    # find all courses
    @courses = Course.search(nil, [:profs, :faculty], [cond], [vals], [:faculty_id, :title])

    # otherwise, render list of courses
    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @courses }
    end
  end

  def search
    @courses = Course.search courses_params[:search]
  end

  # GET /courses/1
  # GET /courses/1.xml
  def show
    @course = Course.find(courses_params[:id])

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @course }
    end
  end

  def correlate
    @course = Course.find(courses_params[:id])
    respond_to do |format|
      format.html
      format.json do
        if [courses_params[:correlate_by], courses_params[:question]].any_nil?
          render :json => "Missing parameters.", :status => :unprocessable_entity
          return
        end

        if courses_params[:correlate_by] == courses_params[:question]
          render :json => "correlate_by and question must be different", :status => :unprocessable_entity
          return
        end

        c = @course.form.get_question(courses_params[:correlate_by])
        q = @course.form.get_question(courses_params[:question])
        if [c,q].any_nil?
          render :json => "Invalid question/correlate_by specified.", :status => :unprocessable_entity
          return
        end

        filter = {:barcode => @course.barcodes }
        data = RT.correlate(@course.form.db_table, c.db_column, q.db_column, filter, true)
        sorted_answers = data.values.map { |v| v.keys }.flatten.uniq.sort_by { |v| v.to_s }
        results = {}
        data.sort_by { |k,v| k.to_s }.each do |k,v|
          k = c.box_text_by_value(k).strip_all_tex if k.is_a?(Integer)
          results[k] = {}
          sorted_answers.each do |kk|
            vv = v[kk] || 0
            kk = q.box_text_by_value(kk).strip_all_tex if kk.is_a?(Integer)
            results[k][kk] = vv
          end
        end
        render :json => results
      end
    end
  end


  # GET /courses/new
  # GET /courses/new.xml
  def new
    @course = Course.new
    @curr_term ||= view_context.get_selected_terms
    if @curr_term.empty?
      flash[:error] = "Cannot create a new course for current term, as there isn’t any current term. Please create a new one first."
      redirect_to :controller => "terms", :action => "index"
    else
      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render :xml => @course }
      end
    end
  end

  # GET /courses/1/edit
  def edit
    @course = Course.find(courses_params[:id])
  end

  # GET /courses/1/preview
  def preview
    @course = Course.find(courses_params[:id])
  end

  # POST /courses
  # POST /courses.xml
  def create
    @course = Course.new(courses_params[:course])

    respond_to do |format|
      if form_lang_combo_valid? && @course.save
        flash[:notice] = 'Course was successfully created.'
        format.html { redirect_to(@course) }
        format.xml  { render :xml => @course, :status => :created, :location => @course }
      else
        flash[:error] = "Selected form and language combination isn’t valid." unless form_lang_combo_valid?
        format.html { render :action => "new" }
        format.xml  { render :xml => @course.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /courses/1
  # PUT /courses/1.xml
  def update
    @course = Course.find(courses_params[:id])
    expire_fragment("preview_courses_#{courses_params[:id]}")

    respond_to do |format|
      checks = form_lang_combo_valid? && !critical_changes?(@course)
      if checks && @course.update_attributes(courses_params[:course])
        flash[:notice] = 'Course was successfully updated.'
        format.html { redirect_to(@course) }
        format.xml  { head :ok }
      else
        if not @course.form.abstract_form_valid?
          flash[:error] = "The selected form is not valid. Please fix it first."
        elsif !form_lang_combo_valid?
          flash[:error] = "The selected form/language combination isn’t valid. #{flash[:error]}"
        elsif critical_changes?(@course)
          flash[:error] = "Some of the changes are critical. Those are currently not allowed."
        else
          flash[:error] = "Could not update the course."
        end

        format.html { render :action => "edit" }
        format.xml  { render :xml => @course.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /courses/1
  # DELETE /courses/1.xml
  def destroy
    @course = Course.find(courses_params[:id])
    # expire preview cache as well
    expire_fragment("preview_courses_#{courses_params[:id]}")

    unless @course.critical?
      begin
        @course.course_profs.each { |cp| cp.destroy }
        @course.tutors.each { |t| t.destroy }
      end
      @course.destroy
    end

    respond_to do |format|
      flash[:error] = 'Course was critical and has therefore not been destroyed.' if @course.critical?
      format.html { redirect_to(courses_url) }
      format.xml  { head :ok }
    end
  end

  # DELETE /courses/drop_prof?course=1&prof=1
  def drop_prof
    @course = Course.find(courses_params[:id])
    unless @course.critical?
      @prof = Prof.find(courses_params[:prof_id])
      @course.profs.delete(@prof)
    end

    respond_to do |format|
      flash[:error] = "Course was critical and therefore prof #{@prof.fullname} has been kept." if @course.critical?
      format.html { redirect_to(@course) }
      format.xml { head :ok }
    end
  end

  def add_prof
    begin
      @course = Course.find(courses_params[:id])
      @prof = Prof.find(courses_params[:courses][:profs])
      @course.profs << @prof

      respond_to do |format|
        format.html { redirect_to(@course) }
        format.xml { head :ok }
      end
    rescue
      flash[:error] = "Couldn’t add prof. Are you sure the course and selected prof exist?"
      respond_to do |format|
        format.html { redirect_to(@course) }
        format.xml  { render :xml => (@course.nil? ? "" : @course.errors),
          :status => :unprocessable_entity }
      end
    end
  end

  def emergency_printing
    @amount = Seee::Config.settings[:emergency_printing_amount]
    @course = Course.find(courses_params[:course_id])
    if request.method.to_s.upcase == "POST"
      exit_codes = []
      @course.course_profs.each do |cp|
        exit_codes << cp.print_execute(@amount)
      end
      if exit_codes.sum == 0
        flash[:notice] = "Should print #{@amount} sheets now for each prof."
      else
        flash[:error] = "Printing returned an error. Call for help."
      end
      redirect_to :course_emergency_printing
    else
      render :action => :emergency_printing
    end
  end

  private
  # looks if critical changes to a course were made and reports them iff
  # the course is critical.
  def critical_changes? course
    # if the term is critical, these fields will not be submitted.
    # supply them from the database instead.
    courses_params[:course][:form_id] ||= course.form.id
    courses_params[:course][:language] ||= course.language
    lang_changed = course.language.to_s != courses_params[:course][:language].to_s
    form_changed = course.form.id.to_s != courses_params[:course][:form_id].to_s
    if course.critical? && (lang_changed || form_changed)
      flash[:error] = "Can’t change the language because the term is critical." if lang_changed
      flash[:error] = "Can’t change the form because the term is critical." if form_changed
      return true
    end
    false
  end

  # Checks if the term actually has the form and if that form
  # actually offers the language selected. Will report any errors.
  def form_lang_combo_valid?
    # if the term is critical, these fields will not be submitted.
    # supply them from the database instead.
    if @course
      courses_params[:course][:form_id] ||= @course.form.id if @course.form
      courses_params[:course][:language] ||= @course.language
      courses_params[:course][:term_id] ||= @course.term.id if @course.term
    end

    # check term has form
    t = Term.find(courses_params[:course][:term_id])
    f = Form.find(courses_params[:course][:form_id])

    unless t && f
      flash[:error] = "Selected term or form not found."
      return false
    end

    unless t.forms.map { |f| f.id }.include?(courses_params[:course][:form_id].to_i)
      flash[:error] = "Form “#{f.name}” (id=#{f.id}) is not " \
                        + "available for term “#{t.title}”"
      return false
    end

    # check form has language
    l = courses_params[:course][:language]
    return true if f.has_language?(l)
    flash[:error] = "There’s no language “#{l}” for form “#{f.name}”"
    false
  end
  private
  def courses_params
    params.permit!#(:id,:prof_id,:search,:correlate_by,:question,course:{})
  end
end
