module Main exposing (..)

import Browser
import Html exposing (Html, div, h4, p, span, text, input)
import Html.Attributes exposing (style, placeholder, type_, required)
import Html.Events exposing (onClick)
import Http
import Json.Decode as Decode
import Svg exposing (path, svg)
import Svg.Attributes exposing (d, fill, viewBox)

import Theme

-- MAIN

main =
  Browser.element
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = view
  }

-- MODEL

type Step = Departure_From_Step | Ticket_Step | Departure_Step | Confirm_Pay_Step

type alias Model =
  { server_url : String
  , step : Step
  , harbour: Maybe Harbour
  , departures : List Departure
  , harbours : List Harbour
  }

type alias Ferry =
  { id : Int
  , name : String
  }

type alias Harbour =
  { id : Int
  , name : String
  }

type alias Operator =
  { id : Int
  , name : String
  , email : String
  , role : String
  }

type alias Departure =
  { id : Int
  , ferry : Ferry
  , harbour : Harbour
  , operator : Operator
  , time : String
  , canceled : Int
  }

ferryDecoder : Decode.Decoder Ferry
ferryDecoder =
  Decode.map2 Ferry
    (Decode.field "id" Decode.int)
    (Decode.field "name" Decode.string)

harbourDecoder : Decode.Decoder Harbour
harbourDecoder =
  Decode.map2 Harbour
    (Decode.field "id" Decode.int)
    (Decode.field "name" Decode.string)

operatorDecoder : Decode.Decoder Operator
operatorDecoder =
  Decode.map4 Operator
    (Decode.field "id" Decode.int)
    (Decode.field "name" Decode.string)
    (Decode.field "email" Decode.string)
    (Decode.field "role" Decode.string)

departureDecoder : Decode.Decoder Departure
departureDecoder =
  Decode.map6 Departure
    (Decode.field "id" Decode.int)
    (Decode.field "ferry" ferryDecoder)
    (Decode.field "harbour" harbourDecoder)
    (Decode.field "operator" operatorDecoder)
    (Decode.field "time" Decode.string)
    (Decode.field "canceled" Decode.int)

type alias Flags =
  { server_url : String
  }

init : Flags -> ( Model, Cmd Msg )
init flags =
  ( { server_url = flags.server_url
    , step = Ticket_Step
    , harbour = Nothing
    , departures = []
    , harbours = []
    }
  , Cmd.batch
      [ getDepartures flags.server_url
      , getHarbours flags.server_url
      ]
  )

type Ticket_Change
  = Ticket_First_Name_Changed String
  | Ticket_Last_Name_Changed String
  | Ticket_Date_Of_Birth_Changed String

-- API

getDepartures : String -> Cmd Msg
getDepartures server_url =
  Http.get
  { url = server_url ++ "/departures"
  , expect = Http.expectJson GotDepartures (Decode.list departureDecoder)
  }

getHarbours : String -> Cmd Msg
getHarbours server_url =
  Http.get
  { url = server_url ++ "/harbours"
  , expect = Http.expectJson GotHarbours (Decode.list harbourDecoder)
  }

-- UPDATE

type Msg
  = StepClicked Step
  | Harbour_Selected Harbour
  | Ticket_Changed Ticket_Change
  | GotDepartures (Result Http.Error (List Departure))
  | GotHarbours (Result Http.Error (List Harbour))

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    StepClicked step ->
      ( { model | step = step }, Cmd.none )

    Harbour_Selected harbour ->
      ( { model | harbour = Just harbour }, Cmd.none )

    Ticket_Changed change ->
      case change of
        Ticket_First_Name_Changed first_name ->
        Ticket_Last_Name_Changed last_name ->
        Ticket_Date_Of_Birth_Changed date_of_birth ->

    GotDepartures result ->
      case result of
        Ok departures ->
          let _ = Debug.log "departures" departures
          in ( { model | departures = departures }, Cmd.none )

        Err error -> let _ = Debug.log "HTTP error" error in ( model, Cmd.none )

    GotHarbours result ->
      case result of
        Ok harbours -> ({ model | harbours = harbours, harbour = List.head harbours }, Cmd.none)
        Err error -> let _ = Debug.log "HTTP error" error in ( model, Cmd.none )

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
    , style "transform" "translateY(0.2rem)"
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

view_step : Step -> Step -> String -> Html Msg
view_step current_step step label =
  div
  [ style "display" "flex"
  , style "align-items" "center"
  , style "justify-content" "center"
  , style "width" "100%"
  , style "height" "100%"
  , style "text-decoration" (if current_step == step then "underline" else "none")
  , onClick (StepClicked step)
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

type alias Radio_Button_Item = { id : Int, name : String }

view_radio_button :
  (Radio_Button_Item -> msg)
  -> Maybe Radio_Button_Item
  -> Radio_Button_Item
  -> Html msg
view_radio_button to_Msg current item =
  div
  [ style "display" "flex"
  , style "align-items" "center"
  , style "justify-content" "center"
  , style "width" "100%"
  , style "height" "3rem"
  , style "background-color" (if current == Just item then Theme.primary else Theme.secondary)
  , style "color" (if current == Just item then Theme.secondary else Theme.text)
  , style "border-radius" "1rem"
  , onClick (to_Msg item)
  ]
  [ span
    [ style "transform" "translateY(0.2rem)" ]
    [ text item.name ]
  ]

view_radio_option :
  (Radio_Button_Item -> msg)
  -> Maybe Radio_Button_Item
  -> Radio_Button_Item
  -> Radio_Button_Item
  -> Html msg
view_radio_option to_Msg selected first second =
  div
  [ style "display" "flex"
  , style "flex-direction" "row"
  , style "gap" "1rem"
  ]
  [ view_radio_button to_Msg selected first
  , view_radio_button to_Msg selected second
  ]

view_step_panel : Model -> Html Msg
view_step_panel model =
  case model.step of
    Departure_From_Step ->
      case
        ( List.filter (\harbour -> harbour.name == "Frederikshavn") model.harbours |> List.head
        , List.filter (\harbour -> harbour.name == "Læsø") model.harbours |> List.head
        )
      of
        ( Just frederikshavn, Just laesoe ) ->
          div []
          [ view_radio_option
              Harbour_Selected
              model.harbour
              frederikshavn
              laesoe
          ]
        _ -> div [] [ text "Kunne ikke indlæse havne." ]

    Ticket_Step ->
      div []
      [ div
        [ style "display" "flex"
        , style "flex-direction" "row"
        , style "gap" "1rem"
        , style "height" "7rem"
        , style "width" "100%"
        , style "padding" "1rem"
        , style "box-sizing" "border-box"
        , style "background-color" Theme.secondary
        , style "border-radius" "1rem"
        ]
        [ div
          [ style "display" "flex"
          , style "align-items" "center"
          , style "justify-content" "center"
          , style "height" "100%"
          , style "width" "9rem"
          ] [ text "Person 1" ]
        , div
          [ style "margin-top" "-1.25rem"
          , style "margin-bottom" "-1.25rem"
          , style "display" "flex"
          , style "flex-direction" "column"
          , style "justify-content" "center"
          , style "align-items" "center"
          , style "gap" "0.25rem"
          ]
          [ div
            [ style "width" "0.5rem"
            , style "height" "0.5rem"
            , style "min-width" "0.5rem"
            , style "min-height" "0.5rem"
            , style "flex-shrink" "0"
            , style "border-radius" "50%"
            , style "background-color" Theme.background
            ] []
          , div
            [ style "height" "80%"
            , style "border-left" ("0.1rem dashed " ++ Theme.background)
            ] []
          , div
            [ style "width" "0.5rem"
            , style "height" "0.5rem"
            , style "min-width" "0.5rem"
            , style "min-height" "0.5rem"
            , style "flex-shrink" "0"
            , style "border-radius" "50%"
            , style "background-color" Theme.background
            ] []
          ]
        , div
          [ style "display" "grid"
          , style "grid-template-columns" "1fr 1fr"
          , style "grid-template-rows" "1fr 1fr"
          , style "gap" "1rem"
          , style "height" "100%"
          , style "width" "100%"
          ]
          [ input
            [ style "height" "2rem"
            , style "width" "100%"
            , style "background-color" Theme.background
            , style "color" Theme.text
            , style "border-radius" "1rem"
            , style "border" "none"
            , style "outline" "none"
            , style "padding" "0.2rem 0rem 0rem 1rem"
            , placeholder "Fornavn"
            , required True
            , onInput (Ticket_Changed << Ticket_First_Name_Changed)
            ] []
          , input
            [ style "height" "2rem"
            , style "width" "100%"
            , style "background-color" Theme.background
            , style "color" Theme.text
            , style "border-radius" "1rem"
            , style "border" "none"
            , style "outline" "none"
            , style "padding" "0.2rem 0rem 0rem 1rem"
            , placeholder "Efternavn"
            , required True
            , onInput (Ticket_Changed << Ticket_Last_Name_Changed)
            ] []
          , div
            [ style "display" "flex"
            , style "flex-direction" "row"
            , style "gap" "1rem"
            , style "height" "2rem"
            , style "width" "100%"
            ]
            [ input
              [ style "height" "2rem"
              , style "width" "100%"
              , style "box-sizing" "border-box"
              , style "background-color" Theme.background
              , style "color" Theme.text
              , style "border-radius" "1rem"
              , style "border" "none"
              , style "outline" "none"
              , style "padding" "0.2rem 0rem 0rem 1rem"
              , style "font-family" "inherit"
              , type_ "date"
              , required True
              , onInput (Ticket_Changed << Ticket_Date_Of_Birth_Changed)
              ]
              []
            ]
          , div
            [ style "display" "flex"
            , style "justify-content" "flex-end"
            , style "align-items" "flex-end"
            , style "width" "100%"
            , style "height" "100%"
            ]
            [ span [ style "transform" "translateY(0.5rem)" ] [ text "-- DKK" ]
            ]
          ]
        ]
      ]

    Departure_Step ->
      div [] (List.map view_departure model.departures)

    Confirm_Pay_Step ->
      div [] [ text "Bekræft og betal" ]

view_departure : Departure -> Html Msg
view_departure departure =
  div []
  [ p [] [ text ("Afgang: " ++ departure.time) ]
  , p [] [ text ("Færge: " ++ departure.ferry.name) ]
  , p [] [ text ("Havn: " ++ departure.harbour.name) ]
  ]

view_ticket_picker : Model -> Html Msg
view_ticket_picker model =
  div
  [ style "display" "flex"
  , style "flex-direction" "column"
  , style "align-items" "center"
  -- Center the step selector vertically, accounting for the 5rem header area.
  , style "padding-top" "calc(50vh - 5rem)"
  ]
  [ div
    [ style "display" "grid"
    , style "grid-template-columns" "1fr 0.1rem 1fr 0.1rem 1fr 0.1rem 2fr"
    , style "align-items" "center"
    , style "text-align" "center"
    , style "background-color" Theme.background
    , style "width" "52rem"
    , style "height" "5rem"
    , style "border-radius" "1rem"
    ]
    [ view_step model.step Departure_From_Step "Udrejse"
    , view_separator
    , view_step model.step Ticket_Step "Billet"
    , view_separator
    , view_step model.step Departure_Step "Afgang"
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
        , onClick (StepClicked Confirm_Pay_Step)
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
            [ Svg.Attributes.width "1rem"
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
    , style "border-radius" "1rem"
    , style "padding" "1rem"
    , style "box-sizing" "border-box"
    ]
    [ view_step_panel model ]
  ]

view : Model -> Html Msg
view model =
  div
  [ style "width" "100%"
  , style "height" "100vh"
  , style "box-sizing" "border-box"
  , style "background-image" "url('/asset/background.jpg')"
  , style "background-size" "cover"
  , style "background-position" "center"
  , style "background-repeat" "no-repeat"
  , style "overflow" "hidden"
  ]
  [ div
    [ style "display" "flex"
    , style "flex-direction" "column"
    , style "width" "100%"
    , style "height" "100%"
    , style "padding" "2rem"
    , style "box-sizing" "border-box"
    , style "overflow-y" "auto"
    ]
    [ view_header
    , view_ticket_picker model
    ]
  ]