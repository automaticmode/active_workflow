this.AgentsIndexPage = class AgentsIndexPage {
  constructor() {
    $("#agents-table").dataTable({
      order: [[1, 'asc']],
      pageLength: 100
    });
  }
};

$(() => Utils.registerPage(AgentsIndexPage, {forPathsMatching: /^agents/}));

