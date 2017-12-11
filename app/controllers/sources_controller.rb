class SourcesController < ApplicationController
  before_action :set_type
  require 'rest-client'
  require 'json'

  load_and_authorize_resource
  skip_load_resource only: [:index, :create]
  skip_authorize_resource only: :index
  layout 'source', except: [:index, :edit, :new]

  # GET /sources
  # GET /sources.json
  def index
    sort_order = Source.sorted_by(params[:sorted_by].presence || nil ) if Source.any?
    query = params[:search].presence || '*'

    sources = Source
      .visible_for(current_user)
      .filter(params.slice(:with_user_shared_to_like, :with_unshared_records, :with_published_records))

    @sources =
        type_class.search(query,
          where: {id: sources.ids},
          page: params[:page], 
          per_page: session[:per_page], 
          order: sort_order, 
          misspellings: {below: 1}
        ) do |body|
          body[:query][:bool][:must] = { query_string: { query: query, default_operator: "and" } }
        end

    respond_to do |format|
      format.html
      format.json { render json: @sources, each_serializer: nil }
      format.js
    end
  end

  # GET /sources/1
  # GET /sources/1.json
  def show
    if @source.type == 'Photo'
      aph = "#{@source.serie}#{@source.number}"
      @ref = ArtefactReference.where(ph_rel: aph)
      @commons = current_user ? current_user_repos.detect{|s| s.name == 'Commons'} : OpenStruct.new(url: "#{Rails.application.secrets.media_host}/api/commons/search", user_access_token: nil)
      @url = "#{@commons.url}?q=#{@source.name}&f=match}"
      begin
        response = RestClient.get(@url, {:Authorization => "Token #{@commons.user_access_token}"})
        @files= JSON.parse(response.body)
      rescue Errno::ECONNREFUSED
        "Server at #{@commons.url} is refusing connection."
        flash.now[:notice] = "Can't connect to #{@commons.url}."
        @files = []
      end

      # Artefact.visible_for(current_user).map{ |a| a.illustrations }  where.not?
      @occurences = @source.occurences.where(artefact: Artefact.visible_for(current_user).all).order(position: :asc)
    end

    @contributions = Hash.new(0)
    @growth = Hash.new(0)
    @source.versions.each do |v|
      @contributions[User.find(v.whodunnit).name] += v.changed_characters_length if v.changed_characters_length.present?
      @growth[v.id] = v.total_characters_length if v.total_characters_length.present?
    end

    respond_to do |format|
      format.html
      format.json { render json: @source, serializer: SourceSerializer }
      format.js
    end
  end

  # GET /sources/new
  def new
    @source = type_class.new(parent_id: params[:parent_id])
  end

  # GET /sources/1/edit
  def edit
  end

  # POST /sources
  # POST /sources.json
  def create
    @source = type_class.new(source_params)

    respond_to do |format|
      if @source.save
        format.html { redirect_to @source, notice: "#{@type} was successfully created." }
        format.json { render :show, status: :created, location: @source }
      else
        format.html { render :new }
        format.json { render json: @source.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /sources/1
  # PATCH/PUT /sources/1.json
  def update
    respond_to do |format|
      if @source.update(source_params)
        format.html { redirect_to @source, notice: "#{@type} was successfully updated." }
        format.json { render :show, status: :ok, location: @source }
      else
        format.html { render :edit }
        format.json { render json: @source.errors, status: :unprocessable_entity }
      end
    end
  end

  def publish
    respond_to do |format|
      if !@source.locked? && @source.update(locked: true)
        @source.versions.create(event: 'publish', whodunnit: current_user.id)
        format.html { redirect_to @source, notice: "#{@type} was successfully published. #{undo_link}" }
        format.json { render :show, status: :ok, location: @source }
      else
        format.html { redirect_to @source, notice: "An error occured." }
        format.json { render json: @source.errors, status: :unprocessable_entity }
      end
    end
  end

  def unlock
    respond_to do |format|
      if @source.locked? && @source.update(locked: false)
        @source.versions.create(event: 'reopen', whodunnit: current_user.id)
        format.html { redirect_to @source, notice: "#{@type} was successfully unlocked." }
        format.json { render :show, status: :ok, location: @source }
      else
        format.html { redirect_to @source, notice: "An error occured." }
        format.json { render json: @source.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /sources/1
  # DELETE /sources/1.json
  def destroy
    @source.destroy
    respond_to do |format|
      format.html { redirect_to sources_url, notice: "#{@type} was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  private
    def set_type 
      @type = type 
    end

    def type 
      Source.types.include?(params[:type]) ? params[:type] : "Source"
    end

    def type_class 
      type.constantize 
    end

    def undo_link
      view_context.link_to("undo", revert_version_path(@source.versions.last), method: :post)
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def source_params
      params.require(type.underscore.to_sym).permit(
        :slug, 
        :identifier_stable, 
        :identifier_temp, 
        :type, 
        :remarks, 
        :parent_id, 
        type_class.jsonb_attributes)
    end
end
