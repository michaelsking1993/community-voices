module Readme
  # One "## " section of README.md, rendered as HTML for the app.
  #
  # The file is read on every call, so the page and the README can't drift:
  # editing the README is the only way to change the page. Links relative to
  # the repo (docs/..., DECISIONS.md, #anchors) point to GitHub, because the
  # app doesn't serve those files.
  class Section
    REPO_URL = "https://github.com/michaelsking1993/community-voices".freeze

    Result = Data.define(:title, :html)

    def self.github_url(href)
      return href if href.match?(%r{\A[a-z][a-z0-9+.-]*:}i) # http:, https:, mailto:

      href.start_with?("#") ? "#{REPO_URL}#{href}" : "#{REPO_URL}/blob/main/#{href.delete_prefix("/")}"
    end

    class Renderer < Redcarpet::Render::HTML
      def link(href, title, content)
        attributes = { href: Section.github_url(href), title: title.presence }.compact
        "<a #{attributes.map { |k, v| %(#{k}="#{ERB::Util.html_escape(v)}") }.join(" ")}>#{content}</a>"
      end
    end

    def initialize(path: Rails.root.join("README.md"))
      @path = path
    end

    # heading: the heading text without "## ". Raises KeyError if it's missing,
    # so a renamed heading fails the spec instead of showing an empty page.
    def call(heading)
      lines = File.readlines(@path, chomp: true)
      start = lines.index("## #{heading}") or raise KeyError, "README.md has no \"## #{heading}\" section"
      finish = lines[(start + 1)..].index { _1.start_with?("## ") }
      body = lines[(start + 1)...(finish ? start + 1 + finish : lines.size)].join("\n")

      Result.new(title: heading, html: markdown.render(body))
    end

    private

    def markdown
      Redcarpet::Markdown.new(Renderer.new(filter_html: true, with_toc_data: true),
                              tables: true, fenced_code_blocks: true, autolink: true, no_intra_emphasis: true)
    end
  end
end
