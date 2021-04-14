(function() {
  let escapeMap = undefined;
  let createEscaper = undefined;
  this.Utils = class Utils {
    static initClass() {

      // _.escape from underscore: https://github.com/jashkenas/underscore/blob/1e68f06610fa4ecb7f2c45d1eb2ad0173d6a2cc1/underscore.js#L1411-L1436
      escapeMap = {
        '&': '&amp;',
        '<': '&lt;',
        '>': '&gt;',
        '"': '&quot;',
        '\'': '&#x27;',
        '`': '&#x60;'
      };

      createEscaper = function(map) {
        const escaper = match => map[match];

        // Regexes for identifying a key that needs to be escaped.
        const source = `(?:${Object.keys(map).join('|')})`;
        const testRegexp = RegExp(source);
        const replaceRegexp = RegExp(source, 'g');
        return function(string) {
          string = string === null ? '' : `${string}`;
          if (testRegexp.test(string)) { return string.replace(replaceRegexp, escaper); } else { return string; }
        };
      };

      this.escape = createEscaper(escapeMap);
    }
    static navigatePath(path) {
      if (!path.match(/^\//)) { path = `/${path}`; }
      window.location.href = path;
    }

    static currentPath() {
      return window.location.href.replace(/https?:\/\/.*?\//g, '');
    }

    static registerPage(klass, options) {
      if (options == null) { options = {}; }
      if (options.forPathsMatching) {
        if (Utils.currentPath().match(options.forPathsMatching)) {
          return window.currentPage = new klass();
        }
      } else {
        return new klass();
      }
    }

    static showDynamicModal(content, param) {
      if (content == null) { content = ''; }
      if (param == null) { param = {}; }
      const { title, body, onHide } = param;
      $("body").append(`\
<div class="modal fade" tabindex="-1" id='dynamic-modal' role="dialog" aria-labelledby="dynamic-modal-label" aria-hidden="true">
  <div class="modal-dialog modal-xl">
    <div class="modal-content">
      <div class="modal-header">
        <h4 class="modal-title" id="dynamic-modal-label"></h4>
        <button type="button" class="close" data-dismiss="modal"><span aria-hidden="true">&times;</span><span class="sr-only">Close</span></button>
      </div>
      <div class="modal-body">${content}</div>
    </div>
  </div>
</div>\
`
      );
      const modal = document.querySelector('#dynamic-modal');
      $(modal).find('.modal-title').text(title || '').end().on('hidden.bs.modal', function() {
        $('#dynamic-modal').remove();
        (typeof onHide === 'function' ? onHide() : undefined);
      });
      if (typeof body === 'function') {
        body(modal.querySelector('.modal-body'));
      }
      $(modal).modal('show');
    }

    static handleDryRunButton(button, data) {
      if (data == null) { data = button.form ? $(':input[name!="_method"]', button.form).serialize() : ''; }
      $(button).prop('disabled', true);
      const cleanup = () => $(button).prop('disabled', false);

      const url = $(button).data('action-url');
      const with_message_mode = $(button).data('with-message-mode');

      if (with_message_mode === 'no') {
        this.invokeDryRun(url, data, cleanup);
      }
      $.ajax(url, {
        method: 'GET',
        data: {
          with_message_mode,
          source_ids: $.map($(".link-region select option:selected"), el => $(el).val())
        },
        success: modal_data => {
          Utils.showDynamicModal(modal_data, {
            body: body => {
              // TODO: unify with agent editors.
              const form = $(body).find('.dry-run-form');
              const payload_editor = form.find('.payload-editor');


              const $textarea = $(".payload-editor").hide();
              const container = 'ace-payload-editor';
              const $container = $(`#${container}`);
              const editor = ace.edit(container);
              $container.data('ace-editor', editor);
              editor.session.setTabSize(2);
              editor.session.setUseSoftTabs(true);
              editor.session.setUseWrapMode(false);
              editor.session.setMode("ace/mode/json");
              editor.session.setValue($textarea.val());

              $(body).find('.dry-run-message-sample').click(e => {
                e.preventDefault();
                const payload = $(e.currentTarget).find(".sample-payload").text();
                editor.session.setValue(payload);
              });

              form.submit(e => {
                let dry_run_data;
                e.preventDefault();
                let json = editor.session.getValue();
                if (json === '') { json = '{}'; }
                try {
                  const payload = JSON.parse(json.replace(/\\\\([n|r|t])/g, "\\$1"));
                  if (payload.constructor !== Object) { throw true; }
                  if (Object.keys(payload).length === 0) {
                    json = '';
                  } else {
                    json = JSON.stringify(payload);
                  }
                } catch (error) {
                  alert('Invalid JSON object.');
                  return;
                }
                if (json === '') {
                  if (with_message_mode === 'yes') {
                    alert('Message is required for this agent to run.');
                    return;
                  }
                  dry_run_data = data;
                  $(button).data('payload', null);
                } else {
                  dry_run_data = `message=${encodeURIComponent(json)}&${data}`;
                  $(button).data('payload', json);
                }
                $(body).closest('[role=dialog]').on('hidden.bs.modal', () => {
                  this.invokeDryRun(url, dry_run_data, cleanup);
              }).modal('hide');
              });
              $(body).closest('[role=dialog]').on('shown.bs.modal', function() {
                $(this).find('.btn-primary').focus();
              });
            },
            title: 'Dry Run',
            onHide: cleanup
          }
          );
        }
      }
      );
    }

    static invokeDryRun(url, data, callback) {
      $('body').css({cursor: 'progress'});
      $.ajax({type: 'POST', url, dataType: 'html', data})
        .always(() => {
          $('body').css({cursor: 'auto'});
      }).done(modal_data => {
          Utils.showDynamicModal(modal_data, {
            title: 'Dry Run Results',
            onHide: callback
          }
          );
        }).fail(function(xhr, status, error) {
          alert(`Error: ${error}`);
          callback();
      });
    }

    static select2TagClickHandler(e, elem) {
      if (e.which === 1) {
        window.location = $(elem).attr('href');
      } else {
        window.open($(elem).attr('href'));
      }
    }
  };
  Utils.initClass();
})();
