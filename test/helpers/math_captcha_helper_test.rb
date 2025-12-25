require "test_helper"

class MathCaptchaHelperTest < ActionView::TestCase
  test "math_captcha_challenge formats question without question mark" do
    captcha = math_captcha_challenge(max: 10)

    assert_includes captcha.keys, :a
    assert_includes captcha.keys, :b
    assert_includes captcha.keys, :op
    assert_includes captcha.keys, :question

    assert_match(/\A\d+ [+-] \d+ =\z/, captcha[:question])
    refute_includes captcha[:question], "?"
  end
end
