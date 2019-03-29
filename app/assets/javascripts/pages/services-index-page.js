this.ServicesIndexPage = class ServicesIndexPage {
  constructor() {
    $("#services-table").dataTable({
      paging: false,
      order: [[0, 'asc']],
      columnDefs: [
        { targets: [2, 3], searchable: false, orderable: false }
      ]
    });
  }
};

$(() => Utils.registerPage(ServicesIndexPage, {forPathsMatching: /^services/}));
