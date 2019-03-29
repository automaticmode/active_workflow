module FeatureHelpers
  def select_agent_type(type)
    select2(type, from: 'Type')

    # Wait for all parts of the Agent form to load:
    expect(page).to have_css('input[type=submit]') # Options editor (Save)
    expect(page).to have_css('.well.description > p') # Markdown description
  end

  def fill_in_editor(field, options)
    text = options[:with]
    # Wait until the editor is ready.
    has_css?(".ace-editor[data-source='\##{field}'")
    execute_script("$(\".ace-editor[data-source='\##{field}']\")" \
                   ".data('ace-editor').setValue(#{text.inspect})")
  end

  def editor_value(field)
    evaluate_script("$('.ace-editor[data-source=\"\##{field}\"]')" \
                   ".data('ace-editor').getValue()")
  end
end
