module Chunking
  # Turns a post's raw Markdown into plain text worth embedding.
  # Quoted replies are removed because the quoted words belong to another
  # post (which has its own chunks); keeping them would double-count them.
  module TextCleaner
    module_function

    INNERMOST_QUOTE = %r{\[quote[^\]]*\](?:(?!\[quote).)*?\[/quote\]}m

    def call(raw)
      without_quotes(raw.to_s)
        .gsub(/```.*?```/m, " [code] ")                    # fenced code blocks
        .gsub(/!\[[^\]]*\]\([^)]*\)/, " ")                 # images
        .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')               # [text](url) -> text
        .gsub(/<[^>]+>/, " ")                              # stray HTML
        .gsub(/\s+/, " ")
        .strip
    end

    # Quoted replies, innermost first, so a quote inside a quote leaves nothing behind.
    def without_quotes(text)
      loop do
        stripped = text.gsub(INNERMOST_QUOTE, " ")
        return stripped if stripped == text

        text = stripped
      end
    end
  end
end
