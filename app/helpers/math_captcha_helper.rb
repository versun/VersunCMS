module MathCaptchaHelper
  def math_captcha_challenge(max: 10, chooser: [ true, false ], rng: Kernel)
    max = max.to_i
    max = 10 if max <= 0

    if chooser.sample
      a = rng.rand(0..max)
      b = rng.rand(0..(max - a))
      op = "+"
    else
      a = rng.rand(0..max)
      b = rng.rand(0..a)
      op = "-"
    end

    question = "#{a} #{op} #{b} ="

    { a:, b:, op:, question: }
  end
end
