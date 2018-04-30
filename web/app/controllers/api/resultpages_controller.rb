class Api::ResultpagesController < ActionController::Base
  def create
    #todo delete old
    p result_params["keys"]
    db_table = result_params["db_table"]
    keys= JSON.parse(result_params["keys"])
    vals =JSON.parse(result_params["vals"])
    q = "INSERT INTO #{db_table} ("
    q << keys.join(", ")
    q << ") VALUES ("
    # inserts right amount of question marks for easy
    # escaping
    q << (["?"]*(vals.size)).join(", ")
    q << ")"
    RT.custom_query_no_result(q,vals)
  end
  def show
    t = params[:id]
    p t
    form = RT.custom_query("SELECT abstract_form FROM #{t}", [], true)
    d = {data:{attributes:form}}
    render json: d
  end
  private
  def result_params
    params.require(:data).require(:attributes).permit!
  end
end
