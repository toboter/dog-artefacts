# t.integer   :archive_id
# t.string    :collection
# t.string    :call_number
# t.string    :temp_call_number
# t.integer   :parent_id
# t.string    :sheet
# t.string    :type
# t.string    :genuineness (Original/Kopie)
# t.string    :material
# t.string    :measurements
# t.string    :title
# t.string    :labeling
# t.string    :provenance
# t.string    :period
# t.string    :author
# t.string    :size
# t.string    :contains
# t.string    :part_of
# t.string    :description
# t.string    :remarks
# t.string    :condition
# t.string    :access_restrictions  (Sperrvermerk)
# t.string    :loss_remarks
# t.string    :location_current
# t.string    :location_history
# t.string    :state
# t.text      :history
# t.string    :relevance
# t.string    :relevance_comment
# t.string    :digitize_remarks
# t.string    :keywords
# t.string    :links

# TODO
# Js  Create Archive from Source.new/edit
# assoc/js connect artefacts to sources + add fields_for &inverse == artfacts_photos (rename to artefact_source?; remove photo_import?)
# render parent attachments with child
# render attachment with artefact
# import photos_import to sources

class Source < ApplicationRecord
  self.inheritance_column = :_type_disabled
  searchkick
  has_paper_trail ignore: [:slug, :updated_at, :locked], 
    meta: {
      version_name: :name, 
      changed_characters_length: :changed_characters,
      total_characters_length: :total_characters
    }
  include Filterable
  extend FriendlyId
  include Nabu
  include Visibility
  acts_as_taggable

  has_closure_tree
  
  belongs_to :archive, counter_cache: true
  has_many :occurences, class_name: "ArtefactPhoto", foreign_key: :source_id
  has_many :artefacts, through: :occurences
  has_many :attachments, dependent: :destroy

  def ph_rel
    "#{ph}#{ph_nr}#{ph_add}"
  end
  def references
    ArtefactReference.where(ph_rel: ph_rel)
  end

  after_commit :reindex_descendants
  #after_save :reslug_descendants, if: :identifier_stable_changed?
  friendly_id :name, use: :slugged

  validates :call_number, presence: { message: "can't be blank. At least use a temporary identifier, next field." }, unless: -> {temp_call_number.present?}

  attr_accessor :add_to_tag_list, :remove_from_tag_list

  accepts_nested_attributes_for :attachments, allow_destroy: true

  def changed_characters
    total = 0
    self.changes.each do |k,v|
      unless k.in?(['id', 'slug', 'locked', 'created_at', 'updated_at', 'parent_id'])
        ocl = v[0].to_s.length
        ncl = v[1].to_s.length
        changes = ocl > ncl ? ocl - ncl : ncl - ocl
        total = total + changes
      end
    end
    return total
  end

  def total_characters
    total = 0
    self.attributes.each do |k,v|
      total = total + v.to_s.length unless k.in?(['id', 'slug', 'locked', 'created_at', 'updated_at', 'parent_id'])
    end
    return total
  end

  # virtual attributes

  def tag_list
    tags.map{|t|  [t.name, t.uuid, t.url].join(';')  }
  end

  def tag_list=(values)
    ctags = []
    values.split(',').each do |term|
      ident = term.split(';')
      ctags << ActsAsTaggableOn::Tag.where(name: ident.first, uuid: ident.second, url: ident.last).first_or_create
    end
    self.tags = ctags
  end

  def should_generate_new_friendly_id?
    (call_number_changed? || sheet_changed?) || super
  end

  # Naming

  def name_tree
    self_and_ancestors.auto_include(false).reverse.map{ |t| t.id }.join(' / ')
  end

  def name
    n = []
    n << call_number
    n << temp_call_number
    n << sheet
    return n.compact.flatten.reject(&:blank?).join(', ')
  end


  # Indexing and search

  def search_data
    attributes.merge(
      artefacts: artefacts.map{|a| [a, a.full_entry].join(' ') },
      tags: tag_list
    )
  end

  def reindex_descendants
    descendants.each do |subject|
      subject.reindex
    end
  end


  # Scopes

  scope :with_published_records, lambda { |flag|
    return nil  if 0 == flag # checkbox unchecked
    published
  }

  scope :with_unshared_records, lambda { |flag|
    return nil  if 0 == flag # checkbox unchecked
    inaccessible
  }

  scope :with_user_shared_to_like, lambda { |user_id|
    return nil if user_id.blank?
    user = User.find(user_id)
    accessible_by(user)
  }

  # Sorting

  def self.sorted_by(sort_option)
    direction = (sort_option =~ /desc$/) ? 'desc' : 'asc'
    case sort_option.to_s
    when /^ident_name_/
      { slug: direction.to_sym }
    when /^created_at_/
      { created_at: direction.to_sym }
    when /^updated_at_/
      { updated_at: direction }
    when /^score_/
      { _score: direction }
    else
      raise(ArgumentError, "Invalid sort option: #{ sort_option.inspect }")
    end
  end
   
  def self.options_for_sorted_by
    [
      ['Relevance asc', 'score_asc'],
      ['Relevance desc', 'score_desc'],
      ['Ident (a-z)', 'ident_name_asc'],
      ['Ident (z-a)', 'ident_name_desc'],
      ['Created (newest first)', 'created_at_desc'],
      ['Created (oldest first)', 'created_at_asc'],
      ['Updated asc', 'updated_at_asc'],
      ['Updated desc', 'updated_at_desc']
    ]
  end



      # set User.current first
      def self.get_photos_from_photo_import(user_id)
        @user = User.find(user_id)
        PaperTrail.whodunnit = @user.id
        PhotoImport.auto_include(false).all.each do |import|
          photo = Photo.auto_include(false).all.type_data_where(serie: import.ph, number: import.ph_nr.to_s, addenda: import.ph_add).first_or_initialize
          photo.call_number = "#{import.ph} #{import.ph_nr}#{import.ph_add}" 
          photo.serie = import.ph
          photo.number = import.ph_nr
          photo.addenda = import.ph_add
          photo.photo_at = import.ph_datum
          photo.description = import.ph_text
          photo.remarks = 'Cross import from xlsx'
          photo.slug = nil
          photo.save!
          ArtefactPhoto.auto_include(false).where(p_rel: import.ph_rel).update_all(source_id: photo.id)
        end
      end

end