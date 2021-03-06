module MetaWeblogStructs
  class Article < ActionWebService::Struct
    member :description,        :string
    member :title,              :string
    member :postid,             :string
    member :url,                :string
    member :link,               :string
    member :permaLink,          :string
    member :categories,         [:string]
    member :mt_text_more,       :string
    member :dateCreated,        :time
  end

  class Category < ActionWebService::Struct
    member :title,        :string
    member :categoryName, :string
    member :description,  :string
    member :htmlUrl,      :string
    member :rssUrl,       :string
  end
  
  class MediaObject < ActionWebService::Struct
    member :bits, :string
    member :name, :string
    member :type, :string
  end

  class Url < ActionWebService::Struct
    member :url, :string
  end
end


class MetaWeblogApi < ActionWebService::API::Base
  inflect_names false

  api_method :getCategories,
    :expects => [ {:blogid => :string}, {:username => :string}, {:password => :string} ],
    :returns => [[MetaWeblogStructs::Category]]

  api_method :getPost,
    :expects => [ {:postid => :string}, {:username => :string}, {:password => :string} ],
    :returns => [MetaWeblogStructs::Article]

  api_method :getRecentPosts,
    :expects => [ {:blogid => :string}, {:username => :string}, {:password => :string}, {:numberOfPosts => :int} ],
    :returns => [[MetaWeblogStructs::Article]]

  api_method :deletePost,
    :expects => [ {:appkey => :string}, {:postid => :string}, {:username => :string}, {:password => :string}, {:publish => :int} ],
    :returns => [:bool]

  api_method :editPost,
    :expects => [ {:postid => :string}, {:username => :string}, {:password => :string}, {:struct => MetaWeblogStructs::Article}, {:publish => :int} ],
    :returns => [:bool]

  api_method :newPost,
    :expects => [ {:blogid => :string}, {:username => :string}, {:password => :string}, {:struct => MetaWeblogStructs::Article}, {:publish => :int} ],
    :returns => [:string]

  api_method :newMediaObject,
    :expects => [ {:blogid => :string}, {:username => :string}, {:password => :string}, {:data => MetaWeblogStructs::MediaObject} ],
    :returns => [MetaWeblogStructs::Url]

end


class MetaWeblogService < RadiantWebService
  web_service_api MetaWeblogApi
  before_invocation :authenticate

  def getCategories(blogid, username, password)
    Page.find_all_by_class_name("PaginatedArchive").collect{ |c| category_dto_from(c) }
  end

  def getPost(postid, username, password)
    page = Page.find(postid)
    article_dto_from(page)
  end

  def getRecentPosts(blogid, username, password, numberOfPosts)
    Page.find(:all, :order => "created_at DESC", :limit => numberOfPosts).collect{ |c| article_dto_from(c) }
  end

  def newPost(blogid, username, password, struct, publish)
    page            = Page.new_with_defaults
    page.class_name = "Page"
    if struct['categories'] && !struct['categories'].empty? 
      page.parent = Page.find_by_class_name_and_title("PaginatedArchive",struct['categories'][0])
    elsif Page.find_by_class_name("PaginatedArchive")
      page.parent = Page.find_by_class_name("PaginatedArchive")
    else
      page.parent = Page.find(1)
    end

    handle_page(page,struct,publish)
    
    if !page.save
      raise page.errors.full_messages * ", "
    end
    
    ResponseCache.instance.expire_response(page.parent.url) if page.parent
    page.id.to_s
  end

  def deletePost(appkey, postid, username, password, publish)
    Page.destroy(postid)
    true
  end

  def editPost(postid, username, password, struct, publish)
    page = Page.find(postid.to_i)
    if struct['categories'] && !struct['categories'].empty? && Page.find_by_class_name_and_title("PaginatedArchive",struct['categories'][0])
      page.parent = Page.find_by_class_name_and_title("PaginatedArchive",struct['categories'][0])
    end
    
    handle_page(page,struct,publish)

    page.save
    
    ResponseCache.instance.expire_response(page.url)
    ResponseCache.instance.expire_response(page.parent.url) if page.parent
    true
  end

  def newMediaObject(blogid, username, password, data)
    resource = Resource.create(:filename => data['name'], :mime => data['type'], :created_at => Time.now)
    resource.write_to_disk(data['bits'])

    MetaWeblogStructs::Url.new("url" => this_blog.file_url(resource.filename))
  end

  def article_dto_from(page)
    MetaWeblogStructs::Article.new(
      :description       => page.part("body").content,
      :title             => page[:title],
      :postid            => page.id.to_s,
      :url               => @location+page.url,
      :link              => @location+page.url,
      :permaLink         => @location+page.url,
      :categories        => (page.parent ? [page.parent[:title]] : nil),
      :dateCreated       => (page.published_at.getutc.to_formatted_s(:db) rescue "")
      )
  end
  
  def category_dto_from(page)
    MetaWeblogStructs::Category.new(
      :title        => page.title,
      :categoryName => page.title,
      :description  => page.title,
      :htmlUrl      => (@location + page.url),
      :rssUrl       => (@location + page.url)
      )
  end
  
  def handle_page(page,struct,publish)
    body     = page.part("body")
    extended = page.part("extended")
    
    if struct['description'].match(/<hr/)
      body.content     = struct['description'].split("<hr")[0]
      extended.content = struct['description']
    elsif struct['mt_text_more']
      body.content     = struct['description']
      extended.content = struct['description']+struct['mt_text_more']
    else
      perex            = (struct['description'] || '').gsub(/<\/?[^>]*>/, "")
      body.content     = "<p>"+(perex.length > 512 ? perex[0..512] : perex)+"</p>"
      extended.content = struct['description'] || ''
    end
    
    body.save
    extended.save
    
    page.title         = struct['title'] || ''
    page.slug          = (struct['title'] || '').strip.downcase.gsub(/[^-a-z0-9~\s\.:;+=_]/, '').gsub(/[\s\.:;=+]+/,'-')
    page.breadcrumb    = struct['title'] || ''
    page.status_id     = publish ? 100 : 1
    page.published_at  = struct['dateCreated'].to_time.getlocal rescue Time.now
  end
end
