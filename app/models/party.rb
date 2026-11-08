class Party
  include Mongoid::Document
  include Mongoid::Timestamps

  STATUSES        = %w[waiting ready seated completed no_show].freeze
  ACTIVE_STATUSES = %w[waiting ready seated].freeze
  SIZE_RANGE      = 1..Restaurant::CAPACITY

  belongs_to :restaurant

  field :token, type: String, default: -> { SecureRandom.urlsafe_base64(16) }
  field :ticket_number, type: Integer
  field :name, type: String
  field :email, type: String
  field :size, type: Integer
  field :status, type: String, default: "waiting"
  field :active, type: Mongoid::Boolean, default: true

  # obviously token cannot be the same
  index({ token: 1 }, { unique: true })
  # To check active in line duplicate email
  index({ email: 1 }, { unique: true, partial_filter_expression: { active: true } })
  # No same ticket number for the same queue?
  index({ restaurant_id: 1, ticket_number: 1 }, { unique: true })
  # No same ticket number with the same status?
  index({ restaurant_id: 1, status: 1, ticket_number: 1 })

  before_validation :normalize_email
  before_validation :sync_active

  validates :name,  presence: true, length: { maximum: 100 }
  validates :email, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP }
  validates :email, uniqueness: { conditions: -> { where(active: true) },
                                  message: "is already on the waitlist" }, if: :active?
  validates :size, numericality: {
    only_integer: true, in: SIZE_RANGE,
    message: "must be #{SIZE_RANGE.min}–#{SIZE_RANGE.max}."
  }
  validates :status, inclusion: { in: STATUSES }
  validates :ticket_number, presence: true


  def to_param
    # party_path(party) => /parties/<token> Override the def bahavior of using id
    token
  end

  # Memoized so the view can call it (and #position) freely without re-querying.
  def parties_ahead
    @parties_ahead ||= Party.where(restaurant_id: restaurant_id, status: "waiting", :ticket_number.lt => ticket_number).count
  end

  def position
    parties_ahead + 1
  end

  private

  def normalize_email
    self.email = email&.strip&.downcase
  end

  def sync_active
    self.active = ACTIVE_STATUSES.include?(status)
  end
end
