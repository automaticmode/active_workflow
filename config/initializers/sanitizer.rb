ALLOWED_TAGS = %w[strong em b i p code pre tt samp kbd var sub sup dfn
                  cite big small address hr br div span h1 h2 h3 h4 h5 h6
                  ul ol li dl dt dd abbr acronym a img blockquote del ins
                  style table thead tbody tr th td].freeze

ALLOWED_ATTRIBUTES = %w[href src width height alt cite datetime title class
                        name xml:lang abbr border cellspacing cellpadding
                        valign style].freeze

ActionView::Base.sanitized_allowed_tags = Set.new(ALLOWED_TAGS)
ActionView::Base.sanitized_allowed_attributes = Set.new(ALLOWED_ATTRIBUTES)
