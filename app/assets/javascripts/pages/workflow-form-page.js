this.WorkflowFormPage = class WorkflowFormPage {
  constructor() {
    this.enabledSelect2();
  }

  format(icon) {
    const originalOption = icon.element;
    return `<i class="fa ${$(originalOption).data('icon')}"></i> ${icon.text}`;
  }

  enabledSelect2() {
    $('.select2-fountawesome-icon').select2({
      width: '100%',
      formatResult: this.format,
      formatSelection: this.format
    });
  }
};

$(() => Utils.registerPage(WorkflowFormPage, {forPathsMatching: /^workflows/}));
