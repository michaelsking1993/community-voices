module Chunking
  # Turns a post's raw Markdown into plain text worth embedding.
  # Quoted replies are removed because the quoted words belong to another
  # post (which has its own chunks); keeping them would double-count them.
  module TextCleaner
    module_function

    def call(raw)
      raw.to_s
         .gsub(%r{\[quote[^\]]*\].*?\[/quote\]}m, " ")    # quoted replies
         .gsub(/```.*?```/m, " [code] ")                    # fenced code blocks
         .gsub(/!\[[^\]]*\]\([^)]*\)/, " ")                 # images
         .gsub(/\[([^\]]+)\]\([^)]*\)/, '\1')               # [text](url) -> text
         .gsub(/<[^>]+>/, " ")                              # stray HTML
         .gsub(/\s+/, " ")
         .strip
    end
  end
end
