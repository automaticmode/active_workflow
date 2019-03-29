$(function() {
  const getFormData = function(elem) {
    const form_data = $("#edit_agent, #new_agent").serializeObject();
    const attribute = $(elem).data('attribute');
    form_data['attribute'] = attribute;
    delete form_data['_method'];
    return form_data;
  };

  window.initializeFormCompletable = function() {
    let returnedResults = {};
    const completableDefaultOptions = input =>
      ({
        results: [
          (returnedResults[$(input).data('attribute')] || {text: 'Options', children: [{id: undefined, text: 'loading ...'}]}),
          {
            text: 'Current',
            children: [{id: $(input).val(), text: $(input).val()}]
          },
          {
            text: 'Custom',
            children: [{id: 'manualInput', text: 'manual input'}]
          },
        ]
      })
    ;

    $("input[role~=validatable], select[role~=validatable]").on('change', e => {
      const form_data = getFormData(e.currentTarget);
      const form_group = $(e.currentTarget).closest('.form-group');
      $.ajax('/agents/validate', {
        type: 'POST',
        data: form_data,
        success(data) {
          form_group.addClass('has-feedback').removeClass('has-error');
          form_group.find('span').addClass('hidden');
          form_group.find('.fa-check').removeClass('hidden');
          returnedResults = {};
        },
        error(data) {
          form_group.addClass('has-feedback').addClass('has-error');
          form_group.find('span').addClass('hidden');
          form_group.find('.fa-times').removeClass('hidden');
          returnedResults = {};
        }
      });
  });

    $("input[role~=validatable], select[role~=validatable]").trigger('change');

    $.each($("input[role~=completable]"), (i, input) =>
      $(input).select2({
        data() {
          return completableDefaultOptions(input);
        }
      }).on("change", function(e) {
        if (e.added && (e.added.id === 'manualInput')) {
          $(e.currentTarget).select2("destroy");
          $(e.currentTarget).val(e.removed.id);
        }
      })
    );

    const updateDropdownData = function(form_data, element, data) {
      returnedResults[form_data.attribute] = {text: 'Options', children: data};
      $(element).trigger('change');
      $("input[role~=completable]").off('select2-opening', select2OpeningCallback);
      $(element).select2('open');
      $("input[role~=completable]").on('select2-opening', select2OpeningCallback);
    };

    var select2OpeningCallback = function(e) {
      const form_data = getFormData(e.currentTarget);
      if (returnedResults[form_data.attribute] && !$(e.currentTarget).data('cacheResponse')) { delete returnedResults[form_data.attribute]; }
      if (returnedResults[form_data.attribute]) { return; }

      $.ajax('/agents/complete', {
        type: 'POST',
        data: form_data,
        success(data) {
          updateDropdownData(form_data, e.currentTarget, data);
        },
        error(data) {
          updateDropdownData(form_data, e.currentTarget, [{id: undefined, text: 'Error loading data.'}]);
        }
      }
      );
    };

    $("input[role~=completable]").on('select2-opening', select2OpeningCallback);

    $("input[type=radio][role~=form-configurable]").change(function(e) {
      const input = $(e.currentTarget).parents().siblings(`input[data-attribute=${$(e.currentTarget).data('attribute')}]`);
      if ($(e.currentTarget).val() === 'manual') {
        input.removeClass('hidden');
      } else {
        input.val($(e.currentTarget).val());
        input.addClass('hidden');
      }
    });
  };
});
