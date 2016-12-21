class ArtefactsController < ApplicationController
  before_action :set_artefact, only: [:show, :edit, :update, :destroy]
  before_action :authorize, except: [:index, :show]

  # GET /artefacts
  # GET /artefacts.json
  def index
    @filterrific = initialize_filterrific(
      Artefact,
      params[:filterrific],
      select_options: {
        sorted_by: Artefact.options_for_sorted_by
      },
    ) or return
    @p_artefacts = @filterrific.find
    @artefacts = @p_artefacts.paginate(:page => params[:page], :per_page => session[:per_page])
    @gmhash = Gmaps4rails.build_markers(@p_artefacts) do |artefact, marker|
      if artefact.utm?
        marker.lat artefact.to_lat_lon('38S').lat
        marker.lng artefact.to_lat_lon('38S').lon
        marker.infowindow "#{artefact.full_entry}#{' ('+artefact.kod+')' if artefact.kod}#{', '+artefact.f_obj if artefact.f_obj}" 
        # Die marker müssen noch abhängig von ihrer Genauigkeit eingefärbt werden. <= 10 ist rot, alles andere blau.
        marker.picture({
          :url => artefact.utmxx <= 10 && artefact.utmyy <= 10 ? "http://maps.google.com/mapfiles/ms/micons/red.png" : "http://maps.google.com/mapfiles/ms/micons/blue.png",
          :width   => 32,
          :height  => 32
        })
      end
    end
#"    
    respond_to do |format|
      format.html
      format.js
    end
 
    # @artefacts = Artefact.search(params[:q]).order(bab_rel: :asc).paginate(:page => params[:page], :per_page => session[:per_page])
  end

  # GET /artefacts/1
  # GET /artefacts/1.json
  def show
    @illustrations_url = URI.encode("#{Rails.application.secrets.media_host}/api/media/search?q=#{@artefact.illustrations.map{|i| i.name}.join(', ') }")
    @resp = Net::HTTP.get_response(URI.parse(@illustrations_url))
    @illustrations = @artefact.illustrations.any? ? JSON.parse(@resp.body) : []
  end

  # GET /artefacts/new
  def new
    @artefact = Artefact.new
  end

  # GET /artefacts/1/edit
  def edit
  end

  # POST /artefacts
  # POST /artefacts.json
  def create
    @artefact = Artefact.new(artefact_params)

    respond_to do |format|
      if @artefact.save
        format.html { redirect_to @artefact, notice: 'Artefact was successfully created.' }
        format.json { render :show, status: :created, location: @artefact }
      else
        format.html { render :new }
        format.json { render json: @artefact.errors, status: :unprocessable_entity }
      end
    end
  end

  # PATCH/PUT /artefacts/1
  # PATCH/PUT /artefacts/1.json
  def update
    respond_to do |format|
      if @artefact.update(artefact_params)
        format.html { redirect_to @artefact, notice: 'Artefact was successfully updated.' }
        format.json { render :show, status: :ok, location: @artefact }
      else
        format.html { render :edit }
        format.json { render json: @artefact.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /artefacts/1
  # DELETE /artefacts/1.json
  def destroy
    @artefact.destroy
    respond_to do |format|
      format.html { redirect_to artefacts_url, notice: 'Artefact was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  private
    # Use callbacks to share common setup or constraints between actions.
    def set_artefact
      @artefact = Artefact.find(params[:id])
    end

    # Never trust parameters from the scary internet, only allow the white list through.
    def artefact_params
      params.require(:artefact).permit(:filterrific, :bab_rel, :grabung, :bab, :bab_ind, :b_join, :b_korr, :mus_sig, :mus_nr, :mus_ind, :m_join, :m_korr, :kod, :grab, :text, :sig, :diss, :mus_id, :standort_alt, :standort, :mas1, :mas2, :mas3, :f_obj, :abklatsch, :abguss, :fo_tell, :fo1, :fo2, :fo3, :fo4, :fo_text, :utm, :utmxx, :utmy, :utmyy, :inhalt, :period, :arkiv, :text_in_archiv, :jahr, :datum, :zeil2, :zeil1, :gr_datum, :gr_jahr, references_attributes: [:id, :ver, :publ, :jahr, :seite, :_destroy], illustrations_attributes: [:id, :ph, :ph_nr, :ph_add, :position, :p_rel, :_destroy], people_attributes: [:id, :person, :titel, :_destroy])
    end
    
end