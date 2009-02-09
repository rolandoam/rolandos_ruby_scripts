#!/usr/bin/env ruby -Ku

require 'cgi'

module WordCounter
  def self.count(words, exclude = nil)
    words = words.gsub(/[^\w\s]/, ' ').split(/\s+/)
    if exclude
      words_exclude = exclude.gsub(/[^\w\s]/, ' ').split(/\s+/)
      words = words - words_exclude
    end
    hash = Hash.new(0)
    words.each { |w|
      next if w.empty?
      hash[w] += 1
    }
    hash.sort { |a,b| b[1] <=> a[1] }
  end

  def self.output_html(words)
    "<html><body><table><tr><th>word</th><th>count</th></tr>" <<
    words.map { |w,c|
      "<tr><td>#{w}</td><td>#{c}</td></tr>"
    }.join('') <<
    "</table></body></html>"
  end

  def self.show_form
    "<html><head></head><body>" <<
    "<form action=\"#\" method=\"post\">" <<
    "<textarea name=\"words\" cols=\"72\" rows=\"10\">here goes your text</textarea><br/>" <<
    "<textarea name=\"exclude\" cols=\"72\" rows=\"10\">excluded words</textarea><br/>" <<
    "<input type=\"submit\" value=\"Count!\"/>" <<
    "</form><br/>(encoding: #{$KCODE})</body></html>\n"
  end
end

if __FILE__ == $0
  cgi = CGI.new
  cgi.out("charset" => $KCODE) do
    unless cgi.params['words'].empty?
      words = WordCounter.count(cgi.params['words'].first, cgi.params['exclude'].first)
      WordCounter.output_html(words)
    else
      WordCounter.show_form
    end
  end
end
