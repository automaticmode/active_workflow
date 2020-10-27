this.WorkflowsIndexPage = class WorkflowsIndexPage {
  constructor() {
    $("#workflows-table").dataTable({
      paging: false,
      order: [[0, 'asc']],
      columnDefs: [
        { targets: 0, orderable: true, searchable: true },
        { targets: '_all', orderable: false, searchable: false },
      ]
    });
    $("#workflows-table .show-description").click(function(e){
        e.preventDefault();
        e.stopPropagation();
        $("#workflows-table .description").slideToggle();
    });
    // Show the info icon to expand workflow descriptions only if there are any.
    if ( $("#workflows-table p.description").length) {
      $("#workflows-table .show-description").show();
    }
  }
};

$(() => Utils.registerPage(WorkflowsIndexPage, {forPathsMatching: /^workflows/}));

