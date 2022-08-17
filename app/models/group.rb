# Maintains group information for a given user on a specific assignment
class Group < ApplicationRecord
  after_create :set_repo_name, :check_repo_uniqueness, :build_repository

  belongs_to :course, inverse_of: :groups
  has_many :groupings
  has_many :submissions, through: :groupings
  has_many :student_memberships, through: :groupings
  has_many :ta_memberships,
           class_name: 'TaMembership',
           through: :groupings
  has_many :assignments, through: :groupings
  has_many :split_pages

  validates :group_name, presence: true, exclusion: { in: Repository.get_class.reserved_locations }
  validates :group_name, uniqueness: { scope: :course_id }
  validates :group_name, length: { maximum: 30 }
  validates :group_name, format: { with: /\A[a-zA-Z0-9\-_ ]+\z/,
                                   message: 'must only contain alphanumeric, hyphen, a blank space, or ' \
                                            'underscore' }
  validates :repo_name, on: :update, format: { with: /\A[a-zA-Z0-9\-_ ]+\z/,
                                               message: 'must only contain alphanumeric, hyphen, a blank ' \
                                                        'space, or underscore' }

  # prefix used for autogenerated group_names
  AUTOGENERATED_PREFIX = 'group_'.freeze

  def repository_relative_path
    File.join(self.course.name, self.repo_name)
  end

  # Returns an autogenerated name for the group using Group::AUTOGENERATED_PREFIX
  # This only works, after a barebone group record has been created in the database
  def get_autogenerated_group_name
    Group::AUTOGENERATED_PREFIX + self.id.to_s.rjust(4, '0')
  end

  def grouping_for_assignment(aid)
    groupings.where(assessment_id: aid).first
  end

  # Returns the URL for externally accessible repos
  def repository_external_access_url
    "#{Settings.repository.url}/#{repository_relative_path}"
  end

  def repository_ssh_access_url
    "#{Settings.repository.ssh_url}/#{repository_relative_path}.git"
  end

  def build_repository
    # create repositories if and only if we are instructor
    return true unless Settings.repository.is_repository_admin

    # This might cause repository collision errors, because when the group
    # maximum for an assignment is set to be one, the student's username
    # will be used as the repository name. This will raise a RepositoryCollision
    # if an instructor uses a csv file with a student appearing as the only member of
    # two different groups (remember: uploading via csv purges old groupings).
    #
    # Because we use the group id as part of the repository name in all other cases,
    # a repo collision *should* never occur then.
    #
    # For more info about the exception
    # See 'self.create' of lib/repo/git_repository.rb.

    begin
      Repository.get_class.create(repo_path, self.course)
    rescue StandardError => e
      # log the collision
      errors.add(:base, self.repo_name)
      m_logger = MarkusLogger.instance
      error_type = e.is_a?(Repository::RepositoryCollision) ? 'a repository collision' : 'an error'
      m_logger.log("Creating group '#{self.group_name}' caused #{error_type} " \
                   "(Repository name was: '#{self.repo_name}'). Error message: '#{e.message}'",
                   MarkusLogger::ERROR)
      raise
    end
    true
  end

  def repo_path
    File.join(Settings.repository.storage, self.repository_relative_path)
  end

  # Yields a repository object, if possible, and closes it after it is finished
  def access_repo(&block)
    Repository.get_class.access(repo_path, &block)
  end

  private

  # Set repository name after new group is created
  def set_repo_name
    # If repo_name has been set already, use this name instead
    # of the autogenerated name.
    if self.repo_name.nil?
      self.repo_name = get_autogenerated_group_name
    end
    self.save(validate: false)
  end

  # Checks if the repository that is about to be created already exists. Used in a
  # after_create callback to check if there will be a repo collision.
  #
  # This raises an error if there will be a repo collision so that the transaction will
  # rollback before the repo itself is actually created (in an after_create_commit callback).
  #
  # Note that this requires the repo_name to be set either explicitly or by calling set_repo_name
  # after the group has been created.
  def check_repo_uniqueness
    return true unless Repository.get_class.repository_exists? repo_path

    self.errors.add(:repo_name, :taken)
    msg = I18n.t 'activerecord.errors.models.group.attributes.repo_name.taken', value: self.repo_name
    raise StandardError, msg
  end
end
