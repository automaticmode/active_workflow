require 'date'
require 'cgi'

module Agents
  class JavaScriptAgent < Agent
    include FormConfigurable

    can_dry_run!

    default_schedule 'never'

    display_name 'Javascript Agent'

    description <<-MD
      The JavaScript Agent allows you to write code in JavaScript that can create and receive messages.  If other Agents aren't meeting your needs, try this one!

      You can put code in the `code` option.

      You can implement `Agent.check` and `Agent.receive` as you see fit.  The following methods will be available on Agent in the JavaScript environment:

      * `this.createMessage(payload)`
      * `this.incomingMessages()` (the returned message objects will each have a `payload` property)
      * `this.memory()`
      * `this.memory(key)`
      * `this.memory(keyToSet, valueToSet)`
      * `this.setMemory(object)` (replaces the Agent's memory with the provided object)
      * `this.deleteKey(key)` (deletes a key from memory and returns the value)
      * `this.credential(name)`
      * `this.credential(name, valueToSet)`
      * `this.options()`
      * `this.options(key)`
      * `this.log(message)`
      * `this.error(message)`
      * `this.escapeHtml(htmlToEscape)`
      * `this.unescapeHtml(htmlToUnescape)`
    MD

    form_configurable :code, type: :text, ace: true, language: :javascript
    form_configurable :expected_receive_period_in_days
    form_configurable :expected_update_period_in_days

    def validate_options
      errors.add(:base, "The 'code' option is required") unless options['code'].present?
    end

    def check
      log_errors do
        execute_js('check')
      end
    end

    def receive(message)
      log_errors do
        execute_js('receive', message)
      end
    end

    def default_options
      js_code = <<-JS
        Agent.check = function() {
          if (this.options('make_message')) {
            this.createMessage({ 'message': 'I made an message!' });
            var callCount = this.memory('callCount') || 0;
            this.memory('callCount', callCount + 1);
          }
        };

        Agent.receive = function() {
          var message = this.incomingMessage();
          this.createMessage({ 'message': 'I got a message!', 'message_was': message.payload });
        }
      JS

      {
        'code' => Utils.unindent(js_code),
        'expected_receive_period_in_days' => '2',
        'expected_update_period_in_days' => '2'
      }
    end

    private

    def execute_js(js_function, incoming_message = [])
      js_function = js_function == 'check' ? 'check' : 'receive'
      context = MiniRacer::Context.new
      context.eval(setup_javascript)

      context.attach('doCreateMessage', ->(y) { create_message(payload: clean_nans(JSON.parse(y))).payload.to_json })
      context.attach('getIncomingMessage', ->() { incoming_message.to_json })
      context.attach('getOptions', ->() { interpolated.to_json })
      context.attach('doLog', ->(x) { log x })
      context.attach('doError', ->(x) { error x })
      context.attach('getMemory', ->() { memory.to_json })
      context.attach('setMemoryKey', lambda do |x, y|
        memory[x] = clean_nans(y)
      end)
      context.attach('setMemory', lambda do |x|
        memory.replace(clean_nans(x))
      end)
      context.attach('deleteKey', ->(x) { memory.delete(x).to_json })
      context.attach('escapeHtml', ->(x) { CGI.escapeHTML(x) })
      context.attach('unescapeHtml', ->(x) { CGI.unescapeHTML(x) })
      context.attach('getCredential', ->(k) { credential(k); })
      context.attach('setCredential', ->(k, v) { set_credential(k, v) })

      context.eval(code)
      context.eval("Agent.#{js_function}();")
    end

    def code
      interpolated['code']
    end

    def set_credential(name, value)
      c = user.user_credentials.find_or_initialize_by(credential_name: name)
      c.credential_value = value
      c.save!
    end

    def setup_javascript
      <<-JS
        function Agent() {};

        Agent.createMessage = function(opts) {
          return JSON.parse(doCreateMessage(JSON.stringify(opts)));
        }

        Agent.incomingMessage = function() {
          return JSON.parse(getIncomingMessage());
        }

        Agent.memory = function(key, value) {
          if (typeof(key) !== "undefined" && typeof(value) !== "undefined") {
            setMemoryKey(key, value);
          } else if (typeof(key) !== "undefined") {
            return JSON.parse(getMemory())[key];
          } else {
            return JSON.parse(getMemory());
          }
        }

        Agent.setMemory = function(obj) {
          setMemory(obj);
        }

        Agent.credential = function(name, value) {
          if (typeof(value) !== "undefined") {
            setCredential(name, value);
          } else {
            return getCredential(name);
          }
        }

        Agent.options = function(key) {
          if (typeof(key) !== "undefined") {
            return JSON.parse(getOptions())[key];
          } else {
            return JSON.parse(getOptions());
          }
        }

        Agent.log = function(message) {
          doLog(message);
        }

        Agent.error = function(message) {
          doError(message);
        }

        Agent.deleteKey = function(key) {
          return JSON.parse(deleteKey(key));
        }

        Agent.escapeHtml = function(html) {
          return escapeHtml(html);
        }

        Agent.unescapeHtml = function(html) {
          return unescapeHtml(html);
        }

        Agent.check = function(){};
        Agent.receive = function(){};
      JS
    end

    def log_errors
      begin
        yield
      rescue MiniRacer::Error => e
        error "JavaScript error: #{e.message}"
      end
    end

    def clean_nans(input)
      if input.is_a?(Array)
        input.map { |v| clean_nans(v) }
      elsif input.is_a?(Hash)
        input.inject({}) { |m, (k, v)| m[k] = clean_nans(v); m }
      elsif input.is_a?(Float) && input.nan?
        'NaN'
      else
        input
      end
    end
  end
end
