require 'watir'

class Translator

  def get_translation(text)
    @wmap ||= {}
    words = text.strip.split(/\s+/)

    if words.length < 4 && @wmap[text]
      @wmap[text]
    else
      @browser.textarea(id: 'inputText').set(text)
      sleep 2
      result = @browser.textarea(id: 'outputText').value
      if result.strip.split(/\s+/).length < 4
        @wmap[text] = result
      end
      puts "RES: #{result} for #{text[0..34]}"
      result
    end
  end

  def convert(text, url)
    # Open Firefox browser
    if !@browser
      @browser = Watir::Browser.new :firefox
      @browser.goto url
      @browser.textarea(id: 'inputText').wait_until(&:present?)
      sleep 3
    end

    text = get_translation(text)
    sleep 2
    text
  end
end


