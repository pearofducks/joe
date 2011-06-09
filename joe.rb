require 'yaml'
require 'English'
require 'singleton'
require 'fileutils'
require 'redcarpet'
require 'haml'
require 'sass'

class Joe
  include Singleton

  def initialize
    @posts = []
  end

  def start
    setup_joe
    process_pres
    render_posts
    generate_indexes
    copy_assets_and_css
  end

  #initializes site paths and which 'index' files should be
  #generated.
  #basepath: the fileroot for joe's assets
  #sitepath: the destination directory for the generated site
  #indexes:  the files joe should look for in _layout for 'indexes'
  #pres:     a 'pre' file is a 'post' before joe does his magic
  def setup_joe
    @basepath = Dir.pwd
    @sitepath = "#{@basepath}/_site"
    @indexes = ["index","date","category"]
    @pres = Dir.glob "#{@basepath}/_posts/*.markdown"
  end

  #reads in all pre files, parses their YAML header, and creates
  #an object for each one.
  def process_pres
    @pres.each do |pre|
      p = Post.new
      current_file_content = File.read pre
      if current_file_content =~ /^(---\s*\n.*?\n?)^(---\s*$\n?)/m
        p.content = $POSTMATCH
        process_header p,YAML.load($1)
      end
      @posts.push p
    end
    @posts.delete_if { |p| p.publish == false }
  end

  #takes all of our post objects and render them to individual html docs
  def render_posts
    @posts.each do |post|
      postpath = "#{@sitepath}/#{File.dirname(post.permalink)}"
      folder_check postpath
      html_out = File.open "#{@sitepath}/#{post.permalink}","w"
      layout_engine = Haml::Engine.new(
        File.read("#{@basepath}/_layouts/#{post.layout}"))
      payload = layout_engine.render(Object.new,:post=>post) { post.content }
      html_out.write payload
      html_out.close
    end
  end

  #generates 'indexes' which are just the html pages where posts can be listed
  def generate_indexes
    @indexes.each do |index|
      html_out = File.open "#{@sitepath}/#{index}.html","w"
      layout_engine = Haml::Engine.new(
        File.read("#{@basepath}/_layouts/#{index}.haml"))
      payload = layout_engine.render(Object.new,:posts=>@posts)
      html_out.write payload
      html_out.close
    end
  end

  #if the _style folder exists, it will tranform .scss files to css files
  #afterward it will copy everything from _public to the site directory
  def copy_assets_and_css
    if File.exists? "#{@basepath}/_style"
      scss_list = Dir.glob("#{@basepath}/_style/*.scss")
      scss_list.each do |scss_file|
        template = File.read(scss_file)
        sass_engine = Sass::Engine.new(template,{:syntax => :scss})
        css_out = File.open("#{@basepath}/_public/css/#{File.basename(scss_file,'.scss')}.css","w")
        css_out.write(sass_engine.render)
        css_out.close
      end
    end
    FileUtils.cp_r "#{@basepath}/_public/.","#{@sitepath}/",:preserve=>true
  end

  def folder_check postpath
    unless File.exist? postpath
      FileUtils.mkdir_p postpath
    end
  end

  def process_header post,yaml
    post.title = yaml[:title]
    post.content = yaml[:content]
    post.layout = yaml[:layout]
    post.publish = yaml[:publish]
    post.date = yaml[:date]
    post.category = yaml[:category]
    post.permalink = "#{post.date.year}/#{post.date.strftime("%m")}/#{post.slug}.html"
  end
end

class Post
  attr_accessor :content, :date, :publish, :layout, :title, :category, :slug, :permalink

  def category= category
    if category.nil?
      category= "default" 
    else
      @category = category.downcase
    end
  end

  def title= title
    if title.nil?
      title= "Default"
    else
      @title = title
      self.slug = title
    end
  end

  def slug= title
    @slug = title.gsub(/\W/, '_').squeeze('_').downcase
  end

  def content= content
    if content.nil?
      content= "None"
    else
      markdown = Redcarpet.new(content,:fenced_code,:smart)
      @content = markdown.to_html
    end
  end

  def layout= layout
    if layout.nil?
      @layout = "post"
    else
      @layout = layout
    end
      @layout += ".haml"
  end

  def publish= publish
    if publish.nil?
      @publish = true
    else
      @publish = publish
    end
  end

  def date= date
    if date.nil?
      @date = Date.today
    else
      @date = Date.parse date
    end
  end
end

Joe.instance.start
