class Api::ResultsController < ActionController::Base
  def create
    parsed = JSON.parse(result_params[:abstract_form])
    p parsed["db_table"]
    f= parsed
    #return if RT.table_exists?(f.db_table)
    # Note that the barcode is only unique for each CourseProf, but
    # not for each sheet. That's why path is used as unique key.
    q = "CREATE TABLE #{f["db_table"]} ("
    p parsed
    f["pages"].each do |pg|
      pg["questions"].each do |quest|
      next if quest["db_column"].nil?
      if quest["db_column"].is_a?(Array)
        quest["db_column"].each do |a|
          q << "#{a} INTEGER, "
        end
      else
        q << "#{quest['db_column']} INTEGER, "
        txt_col = quest["multi"] ? quest["db_column"]["last"] : quest["db_column"]
        q << "#{txt_col}_text VARCHAR(250), " if quest["last_is_textbox"]
      end
    end
    end

    q << "path VARCHAR(255) NOT NULL UNIQUE, "
    q << "barcode INTEGER default NULL, "
    q << "abstract_form TEXT default NULL "
    q << ");"
    puts q
    begin
      RT.custom_query_no_result(q)
      debug "Created #{f['db_table']}"
    rescue => e
      # There is no proper method supported by MySQL, PostgreSQL and
      # SQLite to find out if a table already exists. So, if above
      # command failed because the table exists, selecting something
      # from it should work fine. If it doesn’t, print an error message.
      begin
        RT.custom_query_no_result("SELECT * FROM #{f['db_table']}")
      rescue
        debug "* SQL backend is down/misconfigured"
        debug "* used SQL query is not supported by your SQL backend"
        debug "Query was #{q}"
        debug "Error: "
        pp e
        exit
      end
    end
  end
  def show
    t= params[:id]
    ex= RT.custom_query("SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME= ? ",[t])
    d = {data:{id:t,attributes:{exists:false}}}
    unless ex.empty?
      form = RT.custom_query("SELECT abstract_form FROM #{t}", [], true)
      p form
      form[:exists]=true
      d = {data:{id:t,attributes:form}}
    end
    render json: d
  end
  def failed_questions
    t= params[:result_id]
    f = params[:questions]
    q = "SELECT path, abstract_form, #{f.join(", ")} FROM #{t} WHERE #{f.join("=-1 OR ")}=-1"
    res = RT.custom_query(q)
    d = {data:{id:t,attributes:{res:res}}}
    render json: d
  end
  def value
    p params
    t= params[:result_id]
    path = params[:path]
    col = params[:column]
    res = RT.custom_query("SELECT #{col} FROM #{t} WHERE path = ?", [path], true)[col]
    d = {data:{id:t,attributes:{res:res}}}
    render json: d
  end
  def count_txt
    table = params[:result_id]
    col = params[:col]
    txt_col = params[:txt_col]
    boxes_count = params[:boxes_count]
    sql = "SELECT COUNT(*) AS cnt, #{txt_col} AS val FROM #{table} "
    sql << %(WHERE #{col} = ? AND #{txt_col} <> '' AND #{txt_col} IS NOT NULL )
    sql << "GROUP BY #{txt_col}"
    answ= RT.custom_query(sql, [boxes_count])
    p answ
    d ={ data: {id: table, attributes:{res:answ}}}
    render json: d
  end
  def fp
    table = params[:result_id]
    col = params[:col]
    txt_col = params[:txt_col]
    boxes_count = params[:boxes_count]
    sql = "SELECT abstract_form, path FROM #{table} "
    sql << %(WHERE #{col} = ? AND #{txt_col} IS NULL)
    rows = RT.custom_query(sql, [boxes_count])
    d ={ data: {id: table, attributes:{res:rows}}}
    render json: d
  end
  def current_value
    p params
    table = params[:result_id]
    current_db_column = params[:db_column]
    current_path = params[:path]
    d ={ data: {id: table, attributes:{res:RT.custom_query("SELECT #{current_db_column} FROM #{table} WHERE path = ?", [current_path], true)}}}
    render json: d
  end
  def update_value
    table = params[:result_id]
    field = params[:field]
    current_path = params[:path]
    value = params[:value]
    p current_path
    RT.custom_query_no_result("UPDATE #{table} SET #{field} = ? WHERE path = ?",
                                            [value, current_path])
  end
  def update_txt
    table = params[:result_id]
    txt_col = params[:txt_col]
    current_path = params[:path]
    value = params[:value]
    sql = "UPDATE #{table} SET #{txt_col} = ? WHERE path = ?"
    RT.custom_query_no_result(sql, [value, current_path])
  end
  def find_tutor
    column = params[:column]
    table = params[:result_id]
    source = params[:path]
    data = RT.custom_query("SELECT #{column} FROM #{table} WHERE path = ?", [source], true)
    d ={ data: {id: table, attributes:{res:data}}}
    render json: d
  end
  private
  def result_params
    params.require(:data).require(:attributes).permit!
  end
end
