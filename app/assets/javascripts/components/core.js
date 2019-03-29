$(function() {
  // Help popovers
  $('.hover-help').popover({trigger: 'hover', html: true});

  // Select2 Selects
  $(".select2").select2({width: 'resolve'});

  $(".select2-linked-tags").select2({
    width: 'resolve',
    formatSelection(obj) {
      return `<a href=\"${this.element.data('urlPrefix')}/${obj.id}/edit\" onClick=\"Utils.select2TagClickHandler(event, this)\">${Utils.escape(obj.text)}</a>`;
    }
  });

  // Helper for selecting text when clicked
  $('.selectable-text').each(function() {
    $(this).click(function() {
      const range = document.createRange();
      range.setStartBefore(this.firstChild);
      range.setEndAfter(this.lastChild);
      const sel = window.getSelection();
      sel.removeAllRanges();
      sel.addRange(range);
    });
  });

  // Agent navbar dropdown
  $('.navbar .dropdown.dropdown-hover').hover((function() { $(this).addClass('open'); }), (function() { $(this).removeClass('open'); }));

  // Enable bootstrap tooltips
  $('[data-toggle="tooltip"]').tooltip();
});
