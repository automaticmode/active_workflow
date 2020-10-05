this.AgentsIndexPage = class AgentsIndexPage {
  constructor() {
    function updateDiagram(json) {
      window.updateDiagramStatus && window.updateDiagramStatus(json);
    }

    function timeAgo(date) {
      if (!date) {
        return '';
      }
      var seconds = Math.floor(((new Date().getTime()/1000) - date)),
      interval = Math.floor(seconds / 31536000);

      if (interval > 1) return interval + "y ago";

      interval = Math.floor(seconds / 2592000);
      if (interval > 1) return interval + "m ago";

      interval = Math.floor(seconds / 86400);
      if (interval >= 1) return interval + "d ago";

      interval = Math.floor(seconds / 3600);
      if (interval >= 1) return interval + "h ago";

      interval = Math.floor(seconds / 60);
      if (interval >= 1) return interval + "m ago";

      return "<1m ago";
    }

    var agentsTable = $("#agents-table").dataTable({
      paging: false,
      createdRow: function(row, data, index) {
        if (data.unavailable) {
          $(row).children().each( function(i, td) {
            if ($(td).find('.btn-group').length == 0) {
              $(td).addClass('agent-unavailable');
            }
          });
        }
      },
      columns: [
        {
          data: 'name',
          render: function (data, type, row) {
            if (type == 'display') {
              var workflow_links = row.workflows.map(workflow => {
                return `<a class="badge" style="color:${workflow.fg_color};background-color:${workflow.bg_color};" href="/workflows/${workflow.id}">${workflow.name}</a>`;
              });
              var agentUrl = `/agents/${row.id}`;
              var workflow_id = workflowId();
              if (workflow_id) {
                agentUrl = `${agentUrl}?workflow_id=${workflow_id}`;
              }
              return `<a href="${agentUrl}">${data}</a><br/><span class='text-muted'>${row.human_type}</span><span>${workflow_links}</span>`;
            }
            return data;
          }
        },
        { data: 'schedule' },
        {
          data: 'last_check_at',
          render: function(data, type, row) {
            if (type == 'display') {
              return timeAgo(data);
            }
            return data;
          }
        },
        {
          data: 'last_receive_at',
          render: function(data, type, row) {
            if (type == 'display') {
              return timeAgo(data);
            }
            return data;
          }
        },
        {
          data: 'last_message_at',
          render: function(data, type, row) {
            if (type == 'display') {
              return timeAgo(data);
            }
            return data;
          }
        },
        {
          data: 'messages_count',
          render: function(data, type, row) {
            if (type == 'display') {
              return `<a href="/agents/${row.id}?tab=messages">${data}</a>`;
            }
            return data;
          }
        },
        {
          data: 'working',
          render: function(data, type, row) {
            if (type == 'display') {
              if (data == true) {
                return '<span class="badge badge-success">Yes</span>';
              } else {
                return '<span class="badge badge-danger">No</span>';
              }
            }
            return data;
          }
        },
        {
          data: 'action_menu',
          render: function(data, type, row) {
            if (type == 'display') {
              return `<div class="btn-group btn-group-sm"><button type="button" ` +
              `class="btn btn-primary btn-sm dropdown dropdown-toggle" `+
              `data-toggle="dropdown"><i class="fa fa-th-list"></i> Actions <span class="caret"></span></button>${data}</div>`;
            }
            return data;
          }
        },
      ]
    });

    agentsTable.on('xhr.dt', function(e, settings, json, xhr) {
      if (json) {
        updateDiagram(json);
      }
    });

    // Check if any pop-ups are open or page is inactive (hidden).
    function canUpdate() {
      if ($('#agents-table .dropdown-menu.show').length > 0) {
        return false;
      }
      if ($('.confirm-agent.modal.show').length > 0) {
        return false;
      }
      if (document.hidden === false) {
        return true;
      }
      return false;
    }

    function updateTable(json) {
      var table = agentsTable.api();
      table.clear();
      table.rows.add(json);
      table.draw();
    }

    function workflowId() {
      return $('#agents-table').data('workflow_id');
    }

    function loadData() {
      if (canUpdate()) {
        var url = '/agents/table.json';
        var workflow_id = workflowId();
        if (workflow_id) {
          url = `${url}?workflow_id=${workflow_id}`;
        }
        $.getJSON(url, function(json) {
          updateTable(json);
          updateDiagram(json);
        });
      }
    }
    loadData();

    setInterval(function() {
      loadData();
    }, 2000);

    // Close modal with remote forms after successful submit.
    $(document).on('ajax:success', '.modal', function(event) {
      $('.modal').modal('hide');
    });
  }
};

$(() => Utils.registerPage(AgentsIndexPage, {forPathsMatching: /^(agents|workflows)/}));

