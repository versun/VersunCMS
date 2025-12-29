module MathCaptchaVerification
  include ApplicationHelper

  private

  # 手机端跳过验证码验证
  def skip_captcha_for_mobile?
    mobile_device?
  end

  def math_captcha_expected(max: 10)
    captcha = params.fetch(:captcha, {})

    a = Integer(captcha[:a].to_s, 10)
    b = Integer(captcha[:b].to_s, 10)
    op = captcha[:op].to_s

    return nil unless (0..max).cover?(a) && (0..max).cover?(b)

    expected =
      case op
      when "+"
        a + b
      when "-"
        a - b
      end

    return nil unless expected && (0..max).cover?(expected)

    expected
  rescue ArgumentError, TypeError
    nil
  end

  def math_captcha_valid?(max: 10)
    # 手机端跳过验证
    return true if skip_captcha_for_mobile?

    expected = math_captcha_expected(max:)
    return false if expected.nil?

    answer = params.dig(:captcha, :answer).to_s.strip
    return false if answer.blank?

    Integer(answer, 10) == expected
  rescue ArgumentError, TypeError
    false
  end
end
