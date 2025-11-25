class Redirect < ApplicationRecord
  validates :regex, presence: true
  validates :replacement, presence: true
  validate :validate_regex_pattern

  scope :enabled, -> { where(enabled: true) }

  def match?(path)
    return false unless enabled?
    compiled_regex.match?(path)
  rescue RegexpError
    false
  end

  def apply_to(path)
    return nil unless match?(path)
    path.gsub(compiled_regex, replacement)
  rescue RegexpError
    nil
  end

  private

  def compiled_regex
    @compiled_regex ||= Regexp.new(regex)
  end

  def validate_regex_pattern
    return if regex.blank?

    begin
      Regexp.new(regex)
    rescue RegexpError => e
      errors.add(:regex, "is not a valid regular expression: #{e.message}")
    end
  end
end
