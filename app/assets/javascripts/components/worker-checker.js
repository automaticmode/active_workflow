$(function() {
  let previousJobs = null;

  if ($(".job-indicator").length) {
    var check = function() {
      let sinceId = $("#message-indicator").data("sinceId");

      const query =
        (sinceId != null) ?
          `?since_id=${sinceId}`
        :
          '';
      $.getJSON(`/worker_status${query}`, function(json) {
        for (let method of ['pending', 'awaiting_retry', 'recent_failures']) {
          const count = json[method];
          const elem = $(`.job-indicator[role=${method}]`);
          if (count > 0) {
            const tooltipOptions = {
              title: `${count} jobs ${method.split('_').join(' ')}`,
              delay: 0,
              placement: "bottom",
              trigger: "hover"
            };
            if (elem.is(":visible")) {
              elem.tooltip('dispose').tooltip(tooltipOptions).find(".number").text(count);
            } else {
              elem.tooltip('dispose').tooltip(tooltipOptions).fadeIn().find(".number").text(count);
            }
          } else {
            if (elem.is(":visible")) {
              elem.tooltip('dispose').fadeOut();
            }
          }
        }

        if ((sinceId != null) && (json.message_count > 0)) {
          $("#message-indicator").tooltip('dispose').
                                fadeIn().
                                find(".number").
                                text(json.message_count);
        } else {
          $("#message-indicator").tooltip('dispose').fadeOut();
        }

        $("#message-indicator").data("sinceId", json.max_id);

        const currentJobs = [json.pending, json.awaiting_retry, json.recent_failures];
        if ((document.location.pathname === '/jobs') && ($(".modal[aria-hidden=false]").length === 0) && (previousJobs != null) && (previousJobs.join(',') !== currentJobs.join(','))) {
          if (!document.location.search || (document.location.search === '?page=1')) {
            $.get('/jobs', data => {
              return $("#main-content").html(data);
            });
          }
        }
        previousJobs = currentJobs;

        return window.workerCheckTimeout = setTimeout(check, 2000);
      });
    };

    check();
  }
});
