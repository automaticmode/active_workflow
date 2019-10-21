this.WorkflowShowPage = class WorkflowShowPage {
  constructor() {
  }

  changeModalText() {
    $('.disable-all-agents').click(function() {
      $('#enable-disable-agents .modal-body-action').text('Would you like to disable all agents?');
      $('#workflow-disabled-value').val('true');
    });
    $('.enable-all-agents').click(function() {
      $('#enable-disable-agents .modal-body-action').text('Would you like to enable all agents?');
      $('#workflow-disabled-value').val('false');
    });
  }
};

$(() => Utils.registerPage(WorkflowShowPage, {forPathsMatching: /^workflows/}));

