module Theme exposing (..)

fontFamily : String
fontFamily = "Alyamama"

fontSizeBase : String
fontSizeBase = "16px"

fontWeight : String
fontWeight = "400"

lineHeight : String
lineHeight = "1.6"

text : String
text = "#292929"

background : String
background = "#f7f7f7"

primary : String
primary = "#063b74"

secondary : String
secondary = "#d9d9d9"

accent : String
accent = "#b0c4de"

type alias TypeScale =
  { h1 : String
  , h2 : String
  , h3 : String
  , h4 : String
  , h5 : String
  , h6 : String
  , p : String
  , small : String
  , xSmall : String
  }

typeScale : TypeScale
typeScale =
  { h1 = "3.815rem"
  , h2 = "3.052rem"
  , h3 = "2.441rem"
  , h4 = "1.953rem"
  , h5 = "1.563rem"
  , h6 = "1.25rem"
  , p = "1rem"
  , small = "0.8rem"
  , xSmall = "0.64rem"
  }