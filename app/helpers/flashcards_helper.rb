module FlashcardsHelper
  # Card text is plain text where `backticks` mean code. Escape first, then
  # turn the backticked parts into <code>.
  def card_text(text)
    safe = ERB::Util.html_escape(text).gsub(/`([^`]+)`/, '<code>\1</code>')
    safe.gsub(/\*([^*]+)\*/, '<em>\1</em>').html_safe
  end
end
