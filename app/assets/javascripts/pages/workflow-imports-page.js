this.WorkflowImportsPage = class WorkflowImportsPage {
  constructor() {
    $('textarea.ace-merge-options').each(function() {
      const $textarea = $(this);
      const editorId = $textarea.data("editor");
      $textarea.hide();
      const editor = ace.edit(editorId);
      editor.session.setTabSize(2);
      editor.session.setUseSoftTabs(true);
      editor.session.setUseWrapMode(false);
      editor.session.setMode("ace/mode/json");
      editor.session.setValue($textarea.val());
      $textarea.data("editor", editor);
    });

    // Validate agents_options Json on form submit
    $('form#new_workflow_import').submit(e =>
      $('textarea.ace-merge-options').each(function() {
        const $textarea = $(this);
        const editor = $textarea.data("editor");
        $textarea.val(editor.session.getValue());
        if ($textarea.length) {
          try {
            JSON.parse($textarea.val());
          } catch (err) {
            e.preventDefault();
            alert('Sorry, there appears to be an error in your JSON input. Please fix it before continuing.');
            // TODO: prevent form button from becoming disabled
            return false;
          }
        }
      })
    );
  }
};


$(() => Utils.registerPage(WorkflowImportsPage, {forPathsMatching: /^workflows/}));

