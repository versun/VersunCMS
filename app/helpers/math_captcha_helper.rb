module MathCaptchaHelper
  def math_captcha_challenge(max: 10)
    max = max.to_i
    max = 10 if max <= 0

    if [ true, false ].sample
      a = rand(0..max)
      b = rand(0..(max - a))
      op = "+"
    else
      a = rand(0..max)
      b = rand(0..a)
      op = "-"
    end

    question = "#{a} #{op} #{b} ="

    { a:, b:, op:, question: }
  end
end
