this.MessagesIndexPage = class MessagesIndexPage {
  constructor() {
    $("#messages-table").dataTable({
      pageLength: 100,
      order: [[1, 'asc']],
      columnDefs: [
        { targets: [1, 3], searchable: false },
        { targets: [2, 3], orderable: false }
      ]
    });
  }
};

$(() => Utils.registerPage(MessagesIndexPage, {forPathsMatching: /^messages/}));
