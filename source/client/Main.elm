module Main exposing (..)

import Browser
import Html exposing (Html, div, h4, p, span, text)
import Html.Attributes exposing (style)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import Svg exposing (svg, path)
import Svg.Attributes exposing (d, fill, viewBox)

import Theme

-- MAIN

main = Browser.element
    { init = init
    , update = update
    , subscriptions = subscriptions
    , view = view
    }

-- MODEL

type alias Flags =
  { server_url : String
  }

type alias Model =
  { server_url : String
  , departures : List Departure
  }

type alias Departure =
  { id : Int
  , ferryId : Int
  , harbourId : Int
  , time : String
  , canceled : Int
  }

departureDecoder : Decode.Decoder Departure
departureDecoder =
  Decode.map5 Departure
    (Decode.field "id" Decode.int)
    (Decode.field "ferry_id" Decode.int)
    (Decode.field "harbour_id" Decode.int)
    (Decode.field "time" Decode.string)
    (Decode.field "canceled" Decode.int)

init : Flags -> (Model, Cmd Msg)
init flags =
  ( { server_url = flags.server_url
    , departures = []
    }
  , getDepartures flags.server_url
  )

-- API

getDepartures : String -> Cmd Msg
getDepartures server_url =
  Http.get
    { url = server_url ++ "/departures"
    , expect = Http.expectJson GotDepartures (Decode.list departureDecoder)
    }

-- UPDATE

type Msg = GotDepartures (Result Http.Error (List Departure)) | StepClicked String

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    StepClicked label ->
      let _ = Debug.log "step" label
      in ( model, Cmd.none )

    GotDepartures result ->
      case result of
        Ok departures ->
          let _ = Debug.log "departures" departures
          in ( { model | departures = departures }, Cmd.none )

        Err error ->
          let _ = Debug.log "HTTP error" error
          in ( model, Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions _ = Sub.none

-- VIEW

view_header : Html Msg
view_header =
  div
    [ style "display" "flex"
    , style "align-items" "center"
    , style "width" "100%"
    , style "height" "3rem"
    , style "background-color" Theme.background
    , style "border-radius" "1rem"
    ]
    [ h4
      [ style "color" Theme.primary
      , style "font-size" Theme.typeScale.h4
      , style "transform" "translateY(0.25rem)"
      , style "margin" "1rem"
      ]
      [ text "Læsøfærgen. "
      , span
        [ style "font-size" Theme.typeScale.h6
        , style "color" Theme.accent
        ]
        [ text "Nemt til og fra Læsø" ]
      ]
    ]

view_step : String -> Html Msg
view_step label =
  div
    [ style "display" "flex"
    , style "align-items" "center"
    , style "justify-content" "center"
    , style "width" "100%"
    , style "height" "100%"
    
    , onClick (StepClicked label)
    ]
    [ text label ]

view_separator : Html Msg
view_separator =
  div
    [ style "width" "0.1rem"
    , style "height" "80%"
    , style "background-color" Theme.secondary
    ]
    []

view_departure : Departure -> Html Msg
view_departure departure =
  div []
    [ p [] [ text ("Afgang: " ++ departure.time) ]
    , p [] [ text ("Færge: " ++ String.fromInt departure.ferryId) ]
    , p [] [ text ("Havn: " ++ String.fromInt departure.harbourId) ]
    ]

view : Model -> Html Msg
view model =
  div
    [ style "display" "flex"
    , style "flex-direction" "column"
    , style "width" "100%"
    , style "height" "100vh"
    , style "padding" "2rem"
    , style "box-sizing" "border-box"
    , style "background-image" "url('/asset/background.jpg')"
    , style "background-size" "cover"
    , style "background-position" "center"
    , style "background-repeat" "no-repeat"
    ]
    [ view_header
    , div
        [ style "display" "grid"
        , style "grid-template-rows" "1fr auto 1fr"
        , style "flex-grow" "1"
        , style "justify-items" "center"
        ]
        [ div [] []
        , div
          [ style "display" "grid"
          , style "grid-template-columns" "1fr 0.1rem 1fr 0.1rem 1fr 0.1rem 1fr 0.1rem 2fr"
          , style "align-items" "center"
          , style "text-align" "center"
          , style "background-color" Theme.background
          , style "width" "52rem"
          , style "height" "5rem"
          , style "border-radius" "1rem"
          ]
          [ view_step "Rejsetype"
          , view_separator
          , view_step "Udrejse"
          , view_separator
          , view_step "Billet"
          , view_separator
          , view_step "Afgang"
          , view_separator
          , div
              [ style "width" "100%"
              , style "height" "80%"
              , style "padding" "0 1rem"
              , style "box-sizing" "border-box"
              ]
              [ div
                  [ style "display" "flex"
                  , style "align-items" "center"
                  , style "justify-content" "space-between"
                  , style "width" "100%"
                  , style "height" "100%"
                  , style "background-color" Theme.accent
                  , style "border-radius" "1rem"
                  , style "padding" "0.5rem"
                  , style "padding-left" "1rem"
                  , style "box-sizing" "border-box"
                  , onClick (StepClicked "Bekræft og betal")
                  ]
                  [ text "Bekræft og betal"
                  , div
                      [ style "display" "flex"
                      , style "align-items" "center"
                      , style "justify-content" "center"
                      , style "height" "100%"
                      , style "aspect-ratio" "1 / 1"
                      , style "background-color" Theme.primary
                      , style "border-radius" "1rem"
                      ]
                      [ svg
                          [ viewBox "0 0 16 16"
                          , Svg.Attributes.width "1rem"
                          , Svg.Attributes.height "1rem"
                          , fill Theme.background
                          ]
                          [ path
                              [ d "M12.136.326A1.5 1.5 0 0 1 14 1.78V3h.5A1.5 1.5 0 0 1 16 4.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 0 13.5v-9a1.5 1.5 0 0 1 1.432-1.499zM5.562 3H13V1.78a.5.5 0 0 0-.621-.484zM1.5 4a.5.5 0 0 0-.5.5v9a.5.5 0 0 0 .5.5h13a.5.5 0 0 0 .5-.5v-9a.5.5 0 0 0-.5-.5z" ]
                              []
                          ]
                      ]
                  ]
              ]
          ]
        , div
          [ style "margin-top" "2rem"
          , style "background-color" Theme.background
          , style "width" "52rem"
          , style "height" "25rem"
          , style "border-radius" "1rem"
          ]
          []
        ]
    ]