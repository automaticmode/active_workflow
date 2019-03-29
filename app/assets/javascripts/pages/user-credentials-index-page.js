this.UserCredentialsIndexPage = class UserCredentialsIndexPage {
  constructor() {
    $("#usercredentials-table").dataTable({
      paging: false,
      order: [[0, 'asc']],
      columnDefs: [
        { targets: 1, searchable: false, orderable: false }
      ]
    });
  }
};

$(() => Utils.registerPage(UserCredentialsIndexPage, {forPathsMatching: /^user_credentials/}));
