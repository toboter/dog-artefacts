class ImportsController < ApplicationController
  before_action :authorize
  
  def index
  end

  def artefacts
    Artefact.import(params[:artefacts_file], params[:creator_id])
    redirect_to imports_url, notice: "Artefacts table imported."
  end

  def artefacts_references
    ArtefactReference.destroy_all
    ArtefactReference.import(params[:artefacts_references_file])
    redirect_to imports_url, notice: "ArtefactsReferences table imported."
  end

  def artefacts_photos
    ArtefactPhoto.delete_all
    ArtefactPhoto.import(params[:artefacts_photos_file])
    redirect_to imports_url, notice: "ArtefactsPhotos table imported."
  end

  def artefacts_people
    ArtefactPerson.destroy_all
    ArtefactPerson.import(params[:artefacts_people_file])
    redirect_to imports_url, notice: "ArtefactsPeople table imported."
  end

  def photos
    PhotoImport.import(params[:photos_file])
    redirect_to imports_url, notice: "Photos table imported."
  end

  def transfer_photos
    Photo.get_photos_from_photo_import(params[:transferer_id])
    redirect_to imports_url, notice: "Photos table imported."
  end

  def literature_items_from
    items =[]
    items << ArtefactReference.all.map(&:sync_to_literature)
    redirect_to imports_url, notice: "#{items.flatten.size} entries synced to literature."
  end

  def literature_item_sources_from
    items =[]
    items << ArtefactReference.where.not(source_id: nil).map(&:sync_between_literature_item_and_source)
    redirect_to imports_url, notice: "#{items.flatten.size} entries transfered and synced between sources and literature."
  end

  def update_tag_concepts_from
    tags=[]
    ActsAsTaggableOn::Tag.all.each do |t|
      if t.uuid.present?
        concept = Wrapper::Vocab.find(t.uuid, access_token)
        tags << t.update(concept_data: concept, name: concept['default_label'], url: concept['html_url'])
        t.taggings.each do |o|
          o.taggable.reindex
        end
      end
    end if current_user.is_admin?
    redirect_to imports_url, notice: "#{view_context.pluralize(tags.size, 'concept')} successfuly updated from babylon-online.org/"
  end
end
