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
  }
};

$(() => Utils.registerPage(WorkflowsIndexPage, {forPathsMatching: /^workflows/}));

