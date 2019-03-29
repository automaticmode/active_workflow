this.UserCredentialPage = class UserCredentialPage {
  constructor() {
    const editor = ace.edit("ace-credential-value");
    editor.getSession().setTabSize(2);
    editor.getSession().setUseSoftTabs(true);
    editor.getSession().setUseWrapMode(false);
    editor.getSession().setMode("ace/mode/text");

    const $textarea = $('#user_credential_credential_value').hide();
    editor.getSession().setValue($textarea.val());

    $textarea.closest('form').on('submit', () => $textarea.val(editor.getSession().getValue()));
  }
};

$(() => Utils.registerPage(UserCredentialPage, {forPathsMatching: /^user_credentials\/(\d+|new)/}));
