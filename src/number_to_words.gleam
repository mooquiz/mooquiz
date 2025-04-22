import gleam/int

pub fn number_to_words(n: Int) -> String {
  let sign = case n < 0 {
    True -> "minus "
    False -> ""
  }

  let n = int.absolute_value(n)
  let hundreds = n / 100
  let tens = n % 100 / 10
  let ones = n % 10

  case n {
    0 -> "zero"
    _ -> sign <> hundreds_to_words(hundreds, tens, ones)
  }
}

fn hundreds_to_words(hundreds: Int, tens: Int, ones: Int) -> String {
  case hundreds {
    0 -> ""
    _ ->
      case hundreds {
        1 -> "one hundred"
        2 -> "two hundred"
        3 -> "three hundred"
        4 -> "four hundred"
        5 -> "five hundred"
        6 -> "six hundred"
        7 -> "seven hundred"
        8 -> "eight hundred"
        9 -> "nine hundred"
        _ -> "invalid input"
      }
      <> case tens, ones {
        0, 0 -> ""
        _, _ -> " and "
      }
  }
  <> tens_to_words(tens, ones)
}

fn tens_to_words(tens: Int, ones: Int) -> String {
  case tens {
    0 ->
      case ones {
        0 -> ""
        _ -> ones_to_words(tens, ones)
      }
    1 -> teens_to_words(ones)
    2 -> "twenty" <> ones_to_words(tens, ones)
    3 -> "thirty" <> ones_to_words(tens, ones)
    4 -> "forty" <> ones_to_words(tens, ones)
    5 -> "fifty" <> ones_to_words(tens, ones)
    6 -> "sixty" <> ones_to_words(tens, ones)
    7 -> "seventy" <> ones_to_words(tens, ones)
    8 -> "eighty" <> ones_to_words(tens, ones)
    9 -> "ninety" <> ones_to_words(tens, ones)
    _ -> "invalid input"
  }
}

fn teens_to_words(ones: Int) -> String {
  case ones {
    0 -> "ten"
    1 -> "eleven"
    2 -> "twelve"
    3 -> "thirteen"
    4 -> "fourteen"
    5 -> "fifteen"
    6 -> "sixteen"
    7 -> "seventeen"
    8 -> "eighteen"
    9 -> "nineteen"
    _ -> "invalid input"
  }
}

fn ones_to_words(tens: Int, ones: Int) -> String {
  case tens {
    0 -> ""
    _ ->
      case ones {
        0 -> ""
        _ -> "-"
      }
  }
  <> case ones {
    0 -> ""
    1 -> "one"
    2 -> "two"
    3 -> "three"
    4 -> "four"
    5 -> "five"
    6 -> "six"
    7 -> "seven"
    8 -> "eight"
    9 -> "nine"
    _ -> "invalid input"
  }
}
