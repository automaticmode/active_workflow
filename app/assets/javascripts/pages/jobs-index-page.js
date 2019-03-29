this.JobsIndexPage = class JobsIndexPage {
  constructor() {
    $("#jobs-table").dataTable({
      paging: false,
      order: [[2, 'asc']],
      columnDefs: [
        { targets: [0, 1], orderable: true, searchable: true },
        { targets: [2, 3], orderable: true, searchable: false },
        { targets: '_all', orderable: false, searchable: false },
      ]
    });
  }
};

$(() => Utils.registerPage(JobsIndexPage, {forPathsMatching: /^jobs/}));
