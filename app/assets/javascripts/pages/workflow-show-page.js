this.WorkflowShowPage = class WorkflowShowPage {
  constructor() {
    this.changeModalText();
  }

  changeModalText() {
    $('.disable-all-agents').click(function() {
      $('#workflow-disabled-value').val('true');
      $('#enable-disable-agents .modal-body-action').text('Would you like to disable all agents?');
    });
    $('.enable-all-agents').click(function() {
      $('#workflow-disabled-value').val('false');
      $('#enable-disable-agents .modal-body-action').text('Would you like to enable all agents?');
    });
  }
};

$(() => Utils.registerPage(WorkflowShowPage, {forPathsMatching: /^workflows/}));

