require 'rubygems'
require 'nokogiri'
require 'open-uri'
require 'net/http'
require 'uri'

class Page < ActiveRecord::Base

  attr_accessible :content, :original_url, :title
  before_create :get_content


  def get_content
    url = self.original_url
    full_nokogiri = Nokogiri::HTML( open(url) )
    self.content = full_nokogiri.css('article').inner_html
    self.title = full_nokogiri.css('title').text
    self.meta = full_nokogiri.css('meta').text
    save if !new_record?  #Temporal: Please keep it because it helps me when we call it in the console
  end

  def article_nokogiri
    @article_nokogiri ||= Nokogiri::HTML( content )
  end

  def remove_scripts(nokogiri_content)
    article_nokogiri_content.xpath("//script").remove
  end

  def h1_text
    article_nokogiri.css("h1").text
  end

  def word_count #400-600?
    word = article_nokogiri.css("p").text
    array_words = word.split
    array_words.length  #aprox based on p tags
  end

  def number_of_h1
   article_nokogiri.css("h1").count
  end

  def number_of_h2
    article_nokogiri.css("h2").count
  end

  def number_of_h3
   article_nokogiri.css("h3").count
  end

  def remove_stop_words
    text = article_nokogiri.css("p").text.downcase!
    array_text = text.scan(/\w+/)
    stop_words = ["0", "a", "about", "above", "after", "again", "against", "all", "am", "an", "and", "any", "are", "aren't", "as", "at", "be", "because", "been", "before", "being", "below", "between", "both", "but", "by", "can't", "cannot", "could", "couldn't", "did", "didn't", "do", "does", "doesn't", "doing", "don't", "down", "during", "each", "few", "for", "from", "further", "had", "hadn't", "has", "hasn't", "have", "haven't", "having", "he", "he'd", "he'll", "he's", "her", "here", "here's", "hers", "herself", "him", "himself", "his", "how", "how's", "i", "i'd", "i'll", "i'm", "i've", "if", "in", "into", "is", "isn't", "it", "it's", "its", "itself", "let's", "me", "more", "most", "mustn't", "my", "myself", "no", "nor", "not", "of", "off", "on", "once", "only", "or", "other", "ought", "our", "ours", "ourselves", "out", "over", "own", "same", "shan't", "she", "she'd", "she'll", "she's", "should", "shouldn't", "so", "some", "such", "than", "that", "that's", "the", "their", "theirs", "them", "themselves", "then", "there", "there's", "these", "they", "they'd", "they'll", "they're", "they've", "this", "those", "through", "to", "too", "under", "until", "up", "very", "was", "wasn't", "we", "we'd", "we'll", "we're", "we've", "were", "weren't", "what", "what's", "when", "when's", "where", "where's", "which", "while", "who", "who's", "whom", "why", "why's", "with", "won't", "would", "wouldn't", "you", "you'd", "you'll", "you're", "you've", "your", "yours", "yourself", "yourselves", "re", 'd', 'll', 'm', 't', 's', 've', 'weren', 'haven', 'aren', 'don', 'shouldn', 'shan', 'mustn']
    array_text.reject! { |word| word.to_i != 0 }
    array_text.reject! { |word| stop_words.include?(word) }
    array_text
  end

  def keyword_frequency
    clean_text = remove_stop_words
    freqs = Hash.new(0)
    clean_text.each { |word| freqs[word] +=1 }
    freqs = freqs.sort_by {|x,y| y }
    freqs.reverse!
    frequent_words_array =freqs.each { |word, freq| word+ ' '+freq.to_s}
    frequent_words_array[0...5]
  end

  def number_of_images
    article_nokogiri.css("img").count
  end

  def start_with_text
    content = article_nokogiri.css("body").text
    first_twenty_characters = content[1..20]
    first_twenty_characters.include? "img"
    #output => true if an image is within the first 20 characters
  end

  def alt_image
    article_nokogiri.css('img').map{ |i| i['alt'] }
  end

  def avg_para_length
    para_length_array = []
    article_nokogiri.css("p").each {|para| para_length_array << para.text.length }
    para_length_sum = para_length_array.inject(:+)
    para_count = article_nokogiri.css("p").count
    para_length_sum / para_count
  end

  def text_vs_html
    text_count = article_nokogiri.text.length
    html_count = article_nokogiri.css('html').inner_html.length
    text_count.to_f / html_count.to_f
  end

  def list_of_outgoing_links
    links = article_nokogiri.css('a').map {|link| link['href']}
    #output => array with the list of all links found in the content
  end

  def number_of_outgoing_links
    links = article_nokogiri.css('a').map {|link| link['href']}
    links.count
    #output => number of links in the content
  end

  def self_referring_links
    url = self.original_url
    links = article_nokogiri.css('a').map {|link| link['href']}
    link.include?(url)
    #output => true if link include (self referring) url
  end


# TO DO: Discuss negative tests with team. Wordpress and Tumblr
# seem to have built-in redirects??
  def broken_links_due_syntax
    links = article_nokogiri.css('a').map {|link| link['href']} # output => array of string urls
    broken_syntax_links = []
    links.each do |link|
      url = URI.parse(link)
      url.kind_of?(URI::HTTP) || url.kind_of?(URI::HTTPS)
      broken_syntax_links << url if false
    end
    broken_syntax_links
  end



  def broken_links_code
    links = article_nokogiri.css('a').map {|link| link['href']} # output => array of string urls
    array_code = links.map do |link|
      url = URI.parse(link)
      req = Net::HTTP::Get.new(url.path)
      res = Net::HTTP.start(url.host, url.port) {|http|http.request(req)}
      res.code
    end
     #Output: array with code response for each link ex.200

    # PENDING --->
         # - Need to add call back: https://github.com/collectiveidea/delayed_job
  end
end

    #Message for Testing (Dan): 
      # if (200..307).to_a.include?(code)
      #   "Good Link"
      # else
      #   "Broken Link due to unable to reach the website or server error" #(400's and 500's errors)
      # end


  #Dan (within test):
  #   @keywords_in_url
  #   @keywords_in_meta_description
  #   @meta_description_length
  #   @meta_title
  #   @keyword_density #percentage of keywords on page
  #   @keywords_in_headings

  #Optional:
  #   @font_size_for_p_tags
  #   @page_load_speed #?

  #TO BE DISCUSSED:
  #   @keyword_variations



