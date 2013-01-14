var renderInProgress = false;
var renderTimeout = null;
var edit = null;
if(typeof listify === 'undefined') var listify = false;

function renderPreview() {
  renderInProgress = true;
  $("#rendermsg").html("Rendering…");

  $("#previewbox").load(
    hitme_preview_url,
    { "text": edit.getValue(), "listify": listify },
    function() {
      renderInProgress = false;
      $("#rendermsg").html('<a onclick="renderPreview()">Force Update now</a>');
    }
  );
}

$(document).ready(function() {
  edit = $("#text").data("editor");
  if(!edit) return;
  sess = edit.getSession();

  sess.on('change', function(){
    if(renderTimeout) clearTimeout(renderTimeout);
    if(renderInProgress) return;
    renderTimeout = setTimeout("renderPreview()", 1000);
  });

  renderPreview();
});
