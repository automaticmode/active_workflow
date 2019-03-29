this.UsersIndexPage = class UsersIndexPage {
  constructor() {
    $("#users-table").dataTable({
      paging: false,
      order: [[0, 'asc']],
      columnDefs: [
        { targets: [0, 1], orderable: true, searchable: true },
        { targets: 5, orderable: true, searchable: false },
        { targets: '_all', orderable: false, searchable: false },
      ]
    });
  }
};

$(() => Utils.registerPage(UsersIndexPage, {forPathsMatching: /^admin\/users/}));
