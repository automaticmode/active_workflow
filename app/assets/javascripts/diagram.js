// This is not included in the core application.js bundle.

window.updateDiagram = function(options){
  const scale = (options && options['scale']) || 1;
  const svg = document.querySelector('.agent-diagram svg.diagram');
  const $svg = $(svg);
  const originalWidth = $svg.data('width') || $svg.width();
  const originalHeight = $svg.data('height') || $svg.height();
  $svg.data('width', originalWidth).data('height', originalHeight);
  const width = originalWidth * scale;
  const height = originalHeight * scale;
  $(svg).width(width).height(height);
  const overlay = document.querySelector('.agent-diagram .overlay');
  $(overlay).width(width).height(height);
  const getTopLeft = function(node) {
    const bbox = node.getBBox();
    const point = svg.createSVGPoint();
    point.x = bbox.x + bbox.width;
    point.y = bbox.y;
    return point.matrixTransform(node.getCTM());
  };
  const getBottomLeft = function(node) {
    const bbox = node.getBBox();
    const point = svg.createSVGPoint();
    point.x = bbox.x + bbox.width;
    point.y = bbox.y + bbox.height;
    return point.matrixTransform(node.getCTM());
  };
  $(svg).find('g.node[data-badge-id]').each(function() {
    const tl = getTopLeft(this);
    $(`#${this.getAttribute('data-badge-id')}`, overlay).each(function() {
      const badge = $(this);
      badge.css({
        left: tl.x - (badge.outerWidth()  * (2/3)),
        top:  tl.y - (badge.outerHeight() * (1/3))
      });
    });
  });
  $(svg).find('g.node[data-issues-id]').each(function() {
    const bl = getBottomLeft(this);
    $(`#${this.getAttribute('data-issues-id')}`, overlay).each(function() {
      const issues = $(this);
      issues.css({
        left: bl.x - (issues.outerWidth()  * (2/3)),
        top:  bl.y - (issues.outerHeight() * (2/3))
      });
    });
  });
};

window.updateDiagramStatus = function(json) {
  var setBadge = function(agent_id, count) {
    var selector = `#b${agent_id}`;
    if (count > 0) {
      $(selector).show();
      $(`${selector}`).text(count);
      $(`${selector}`).attr('title', `${count} messages created`);
    } else {
      $(selector).hide();
    }
  };
  var setIssues = function(agent_id, issues) {
    var selector = `#i${agent_id}`;
    if (issues) {
      $(selector).show();
      $(selector).attr('title', `Issues found with this agent. Click to go to the agent's Details tab for more details.`);
    } else {
      $(selector).hide();
    };
  };
  for(const agent of json) {
    setBadge(agent.id, agent.messages_count);
    setIssues(agent.id, agent.issues);
  }
}

window.setupDiagram = function() {
  let updateVisibility = (show) => {
    const $toggle = $('#show-diagram-toggle');
    const $diagram = $('.overview-diagram');
    if (show) {
      $diagram.removeClass('hidden');
      window.updateDiagram({scale: 0.8});
      $toggle.find('.hide').removeClass('hidden');
      $toggle.find('.show').addClass('hidden');
    } else {
      $diagram.addClass('hidden');
      $toggle.find('.hide').addClass('hidden');
      $toggle.find('.show').removeClass('hidden');
    }
  }
  $('#show-diagram-toggle').on('click', function(e) {
    e.preventDefault();
    const $diagram = $('.overview-diagram');
    const visible = !$diagram.hasClass('hidden');
    const show = !visible;
    updateVisibility(show);
  });
  const $diagram = $('.overview-diagram');
  const visible = !$diagram.hasClass('hidden');
  updateVisibility(visible);

  // Setup on hover hightlights for agents and workflows.
  $('.has-agents').each( function() {
    $(this).hover(function() {
      const agents = $(this).data('agents');
      window.highlightDiagram(agents,
        { bgColor: $(this).data('bgcolor'), fgColor: $(this).data('fgcolor') }
      );
    },
    function() {
      window.highlightDiagram([]);
    });
  });
};

window.highlightDiagram = function(agents, options = {}) {
  let bgColor = options['bgColor'];
  let fgColor = options['fgColor'];
  $('.node.highlight').each(function() {
    $(this).find('text').css('fill', '#ffffff');
    $(this).find('path').css('fill', 'none');
    $(this).removeClass('highlight');
  });
  let highlight = function($node, color, bg) {
    $node.addClass('highlight');
    $node.find('text').css('fill', fgColor);
    $node.find('path').css('fill', bgColor);
  }
  agents.forEach( (agent_id) => {
    let $node = $('.node[data-agent-id="' + agent_id + '"]');
    highlight($node, fgColor, bgColor);
  });
}

$(() => window.setupDiagram());
