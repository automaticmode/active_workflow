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
  }
};

$(() => Utils.registerPage(WorkflowsIndexPage, {forPathsMatching: /^workflows/}));

