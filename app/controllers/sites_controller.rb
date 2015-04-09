class SitesController < ApplicationController
  before_filter :authorize
  
  def index
    crawl = Crawl.using(:processor).find(params[:id])
    @sites = crawl.sites.all
  end
  
  def show
    @site = Site.using(:processor).find(params[:id])
    @stats_chart = Crawl.site_stats(params[:id])
  end
  
  def all_urls
    @site = Site.using(:processor).find(params[:id])
    @urls = @site.pages.limit(50).uniq
  end
  
  def broken
    @crawl = Crawl.using(params["processor_name"]).find(params[:id])
    # @broken = @crawl.pages.where(status_code: '404').limit(50).uniq
    @broken = @crawl.pages.where(status_code: '404')
    @pages = @broken.page(params[:page]).per_page(25)
    
    respond_to do |format|
      format.html
      format.csv { send_data @broken.to_csv }
    end
    
  end

  def available
    
    @crawl = Crawl.using(params["processor_name"]).find(params[:id])
    
    if @crawl.status == 'running'
      @available = @crawl.save_available_sites
    elsif @crawl.available_sites.count > 0 && @crawl.available_sites[0].count > 7
      @available = @crawl.available_sites
    else
      @available = @crawl.save_available_sites
    end
    
    # @available = Rails.cache.fetch(["crawl/#{params[:id]}/available/#{params["processor_name"]}"]){Page.using(params["processor_name"]).where(crawl_id: params[:id], available: 'true')}

    # if !@crawl.moz_da.nil? && !@crawl.majestic_tf.nil?
    #   @pages = @available.where('pages.da >= ? AND pages.trustflow >= ?', @crawl.moz_da, @crawl.majestic_tf).order("#{sort} DESC").page(params[:page]).per_page(25)
    # elsif !@crawl.moz_da.nil?
    #   @pages = @available.where('pages.da >= ?', @crawl.moz_da).order("#{sort} DESC").page(params[:page]).per_page(25)
    # elsif !@crawl.majestic_tf.nil?
    #   @pages = @available.where('pages.trustflow >= ?', @crawl.majestic_tf).order("#{sort} DESC").page(params[:page]).per_page(25)
    # else
    #   @pages = @available.order("#{sort} DESC").page(params[:page]).per_page(25)
    # end
    
    page = params[:page].nil? ? 1 : params[:page].to_i
    sort = params[:sort].nil? ? 2 : params[:sort].to_i
    
    respond_to do |format|
      format.csv { send_data @crawl.available_to_csv }
      format.html { @pages = @available.sort_by{|k|k[sort].to_i}.reverse.paginate(:page => page, :per_page => 25) }
    end
    
  end
  
  def save_bookmarked
    Page.using(params["processor_name"]).where(id: params[:page_ids]).update_all(bookmarked: true)
    redirect_to bookmarked_sites_path(params[:id])
  end
  
  def unbookmark
    Page.using(params["processor_name"]).where(id: params[:page_ids]).update_all(bookmarked: false)
    redirect_to bookmarked_sites_path(params[:id])
  end
  
  def bookmarked
    @crawl = Crawl.using(params["processor_name"]).find(params[:id])
    sort = params[:sort].nil? ? 'id' : params[:sort]
    @bookmarked = @crawl.pages.where(bookmarked: true)
    @pages = @bookmarked.order("#{sort} DESC").page(params[:page]).per_page(25)
    
    respond_to do |format|
      format.html
      format.csv { send_data @bookmarked.to_csv }
    end
    
  end
  
end
