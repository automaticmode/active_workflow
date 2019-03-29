this.AgentShowPage = class AgentShowPage {
  constructor() {
    let tab;
    $(".agent-show #show-tabs a[href='#logs'], #logs .refresh").on("click", this.fetchLogs);
    $(".agent-show #show-tabs a[href='#messages'], #messages .refresh").on("click", e => { e.preventDefault(); this.fetchMessages() });
    $(".agent-show #logs .clear").on("click", this.clearLogs);
    $(".agent-show #memory .clear").on("click", this.clearMemory);
    $(".agent-show #messages .clear").on("click", this.clearMessages.bind(this));
    $('#toggle-memory').on("click", this.toggleMemory);

    this.agentId = $('#messages').closest("[data-agent-id]").data("agent-id");

    // Trigger tabs when navigated to.
    if (tab = __guard__(window.location.href.match(/tab=(\w+)\b/i), x => x[1])) {
      if (["details", "logs", "messages"].includes(tab)) {
        $(`.agent-show .nav-pills li a[href='#${tab}']`).click();
      }
    }
  }

  clearMessages(e) {
    const page = this;
    const agentId = this.agentId;
    e.preventDefault();
    if (confirm('Are you sure you want to delete all messages emited by this agent?')) {
      $("#messages .spinner").show();
      $("#message .refresh, #messages .clear").hide();
      // TODO: json/pagination.
      $.ajax({
        url: `/agents/${agentId}/remove_messages`,
        method: 'POST',
        data: { _method: 'delete' },
        success: data => {
          $("#messages .spinner").stop(true, true).fadeOut(() => $("#messages .refresh, #messages .clear").show());
          page.fetchMessages();
        },
        dataType: 'json'});
    }
  }

  fetchMessages() {
    const page = this;
    const agentId = this.agentId;
    $("#messages .spinner").show();
    $("#messages .refresh, #messages .clear").hide();
    // TODO: json/pagination.
    $.get(`/agents/${agentId}/messages`, html => {
      $("#messages .messages").html(html);
      $("#messages-table").dataTable({
        pageLength: 100,
        order: [[0, 'asc']],
        columnDefs: [
          { targets: [0, 2], searchable: false },
          { targets: [1, 2], orderable: false }
        ]
      });
      $("#messages .spinner").stop(true, true).fadeOut(() => $("#messages .refresh, #messages .clear").show());
      $("#messages .messages .message-show").each(function() {
        const $button = $(this);
        $button.on('click', function(e) {
          e.preventDefault();
          Utils.showDynamicModal('<pre></pre>', {
            title: 'Message',
            body(body) {
              $.get($button.data('url'), html => {
                $(body).html(html);
                const $textarea = $("#message_payload").hide();
                const container = 'message_payload_editor';
                const $container = $(`#${container}`);
                const editor = ace.edit(container);
                editor.setOptions({
                  readOnly: true,
                  minLines: 20,
                  maxLines: 20
                });
                $container.data('ace-editor', editor);
                editor.session.setTabSize(2);
                editor.session.setUseSoftTabs(true);
                editor.session.setUseWrapMode(false);
                editor.session.setMode("ace/mode/json");
                editor.session.setValue($textarea.val());
              });
            }
          });
        });
      });
      $("#messages .messages .message-reemit").each(function() {
        const $button = $(this);
        $button.on('click', function(e) {
          e.preventDefault();
          if (confirm('Are you sure you want to duplicate this message and emit the new one now?')) {
            $.post($button.data('url'), data => {
              page.fetchMessages();
            },
            'json');
          }
        });
      });
      $("#messages .messages .message-delete").each(function() {
        const $button = $(this);
        $button.on('click', function(e) {
          e.preventDefault();
          if (confirm('Are you sure?')) {
            $.post($button.data('url'), { _method: 'delete' }, data => {
              page.fetchMessages();
            },
            'json');
          }
        });
      });
    });
  }

  fetchLogs(e) {
    const agentId = $(e.target).closest("[data-agent-id]").data("agent-id");
    e.preventDefault();
    $("#logs .spinner").show();
    $("#logs .refresh, #logs .clear").hide();
    $.get(`/agents/${agentId}/logs`, html => {
      $("#logs .logs").html(html);
      $("#logs-table").dataTable({
        pageLength: 100,
        order: [[1, 'asc']],
        columnDefs: [
          { targets: [1, 2], searchable: false },
          { targets: [0, 2], orderable: false }
        ]
      });
      $("#logs .logs .show-log-details").each(function() {
        const $button = $(this);
        $button.on('click', function(e) {
          e.preventDefault();
          Utils.showDynamicModal('<pre></pre>', {
            title: $button.data('modal-title'),
            body(body) {
              $(body).find('pre').text($button.data('modal-content'));
            }
          }
          );
        });
      });

      $("#logs .spinner").stop(true, true).fadeOut(() => $("#logs .refresh, #logs .clear").show());
    });
  }

  clearLogs(e) {
    if (confirm("Are you sure you want to clear all logs for this Agent?")) {
      const agentId = $(e.target).closest("[data-agent-id]").data("agent-id");
      e.preventDefault();
      $("#logs .spinner").show();
      $("#logs .refresh, #logs .clear").hide();
      $.post(`/agents/${agentId}/logs/clear`, { "_method": "DELETE" }, html => {
        $("#logs .logs").html(html);
        $("#show-tabs li a.recent-errors").removeClass('recent-errors');
        $("#logs .spinner").stop(true, true).fadeOut(() => $("#logs .refresh, #logs .clear").show());
      });
    }
  }

  toggleMemory(e) {
    e.preventDefault();
    if ($('pre.memory').hasClass('hidden')) {
      $('pre.memory').removeClass('hidden');
      $('#toggle-memory').text('Hide');
    } else {
      $('pre.memory').addClass('hidden');
      $('#toggle-memory').text('Show');
    }
  }

  clearMemory(e) {
    if (confirm("Are you sure you want to completely clear the memory of this Agent?")) {
      const agentId = $(e.target).closest("[data-agent-id]").data("agent-id");
      e.preventDefault();
      $("#memory .spinner").css({display: 'inline-block'});
      $("#memory .clear").hide();
      $.post(`/agents/${agentId}/memory`, { "_method": "DELETE" })
        .done(() =>
          $("#memory .spinner").fadeOut(() => $("#memory + .memory").text("{\n}\n"))).fail(() =>
          $("#memory .spinner").fadeOut(() => $("#memory .clear").css({display: 'inline-block'}))
      );
    }
  }
};

$(() => Utils.registerPage(AgentShowPage, {forPathsMatching: /^agents\/\d+/}));

function __guard__(value, transform) {
  return (typeof value !== 'undefined' && value !== null) ? transform(value) : undefined;
}
