class UrlValidator < ActiveModel::EachValidator
  def validate_each(record, attribute, value)
    unless value =~ /\A#{URI::DEFAULT_PARSER.make_regexp(%w[http https])}\z/
      record.errors.add(attribute, options[:message] || "is not a valid URL")
    end
  end
end
