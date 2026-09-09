module Main exposing (..)

import Browser
import Html exposing (Html, div, h4, p, span, text, input)
import Html.Attributes exposing (class, classList, placeholder, required, type_)
import Html.Events exposing (onBlur, onClick, onInput)
import Http
import Json.Decode as Decode
import Svg exposing (path, svg)
import Svg.Attributes exposing (d, fill, viewBox)


-- MAIN

main =
  Browser.element
  { init = init
  , update = update
  , subscriptions = subscriptions
  , view = view
  }

-- MODEL

temporary_developer_customer_id : Int
temporary_developer_customer_id = 1

type Step = Departure_From_Step | Ticket_Step | Departure_Step | Confirm_Pay_Step

type alias Model =
  { server_url : String
  , step : Step
  , departures : List Departure
  , harbours : List Harbour
  , harbour : Maybe Harbour
  , ticket_requests : List Ticket_Request
  , ticket_responses : List Ticket_Response
  , is_create_ticket_expanded : Bool
  }

type alias Ferry =
  { id : Int
  , name : String
  }

type alias Harbour =
  { id : Int
  , name : String
  }

type alias User =
  { id : Int
  , name : String
  , email : String
  , role : String
  }

type alias Departure =
  { id : Int
  , ferry : Ferry
  , harbour : Harbour
  , user : User
  , time : String
  , canceled : Int
  }

type alias Ticket_Request =
  { id : Int
  , departure : Departure
  , user : User
  , category : String
  , name : Maybe String
  , birthday : Maybe String
  , variant : Maybe String
  , identification : Maybe String
  }

type alias Person_Data = { name : String, birthday : String }

type Variant = Car | Truck | Bicycle
type alias Vehicle_Data = { variant : Variant, identification : String }

type Category = Person Person_Data | Pet | Breakfast | Firstclass | Vehicle Vehicle_Data

type alias Ticket_Response =
  { departure_id : Int
  , user_id : Int
  , category : Category
  }

ferriesDecoder : Decode.Decoder Ferry
ferriesDecoder =
  Decode.map2 Ferry
    (Decode.field "id" Decode.int)
    (Decode.field "name" Decode.string)

harboursDecoder : Decode.Decoder Harbour
harboursDecoder =
  Decode.map2 Harbour
    (Decode.field "id" Decode.int)
    (Decode.field "name" Decode.string)

usersDecoder : Decode.Decoder User
usersDecoder =
  Decode.map4 User
    (Decode.field "id" Decode.int)
    (Decode.field "name" Decode.string)
    (Decode.field "email" Decode.string)
    (Decode.field "role" Decode.string)

departuresDecoder : Decode.Decoder Departure
departuresDecoder =
  Decode.map6 Departure
    (Decode.field "id" Decode.int)
    (Decode.field "ferry" ferriesDecoder)
    (Decode.field "harbour" harboursDecoder)
    (Decode.field "user" usersDecoder)
    (Decode.field "time" Decode.string)
    (Decode.field "canceled" Decode.int)

ticketsDecoder : Decode.Decoder Ticket_Request
ticketsDecoder =
  Decode.map8 Ticket_Request
    (Decode.field "id" Decode.int)
    (Decode.field "departure" departuresDecoder)
    (Decode.field "user" usersDecoder)
    (Decode.field "category" Decode.string)
    (Decode.field "name" (Decode.nullable Decode.string))
    (Decode.field "birthday" (Decode.nullable Decode.string))
    (Decode.field "variant" (Decode.nullable Decode.string))
    (Decode.field "identification" (Decode.nullable Decode.string))

type alias Flags =
  { server_url : String
  }

init : Flags -> ( Model, Cmd Msg )
init flags =
  ( { server_url = flags.server_url
    , step = Ticket_Step
    , harbour = Nothing
    , ticket_requests = []
    , ticket_responses = []
    , departures = []
    , harbours = []
    , is_create_ticket_expanded = False
    }
  , Cmd.batch
      [ getHarbours flags.server_url
      ]
  )

type Ticket_Field = Ticket_First_Name | Ticket_Last_Name | Ticket_Date_Of_Birth

-- API

getDepartures : String -> Int -> Cmd Msg
getDepartures server_url harbour_id =
  Http.get
  { url = server_url ++ "/departures?harbour_id=" ++ String.fromInt harbour_id
  , expect = Http.expectJson GotDepartures (Decode.list departuresDecoder)
  }

getHarbours : String -> Cmd Msg
getHarbours server_url =
  Http.get
  { url = server_url ++ "/harbours"
  , expect = Http.expectJson GotHarbours (Decode.list harboursDecoder)
  }

getTickets : String -> Int -> Cmd Msg
getTickets server_url user_id =
  Http.get
  { url = server_url ++ "/tickets?user_id=" ++ String.fromInt user_id
  , expect = Http.expectJson GotTicketRequests (Decode.list ticketsDecoder)
  }

-- UPDATE

type Msg
  = StepClicked Step
  | Harbour_Selected Harbour
  | Create_Ticket_Clicked
  | Ticket_Validate Ticket_Field
  | Ticket_Changed Ticket_Field String
  | GotDepartures (Result Http.Error (List Departure))
  | GotHarbours (Result Http.Error (List Harbour))
  | GotTicketRequests (Result Http.Error (List Ticket_Request))

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    StepClicked step ->
      case ( step, model.harbour ) of
          ( Departure_Step, Just harbour ) ->
            ( { model | step = step }, getDepartures model.server_url harbour.id )

          _ -> ( { model | step = step }, Cmd.none )

    Harbour_Selected harbour -> ( { model | harbour = Just harbour }, Cmd.none )
    Ticket_Validate field ->
        case field of
          Ticket_First_Name -> let _ = Debug.log "Validate first name" () in ( model, Cmd.none )
          Ticket_Last_Name -> let _ = Debug.log "Validate last name" () in ( model, Cmd.none )
          Ticket_Date_Of_Birth -> let _ = Debug.log "Validate date of birth" ()
                                  in ( model, Cmd.none )

    Create_Ticket_Clicked -> ( { model | is_create_ticket_expanded = True }, Cmd.none )

    Ticket_Changed field value ->
      case field of
          Ticket_First_Name -> let _ = Debug.log "First name input" value in ( model, Cmd.none )
          Ticket_Last_Name -> let _ = Debug.log "Last name input" value in ( model, Cmd.none )
          Ticket_Date_Of_Birth -> let _ = Debug.log "Date of birth input" value
                                  in ( model, Cmd.none )

    GotDepartures result ->
      case result of
        Ok departures ->
          let _ = Debug.log "departures" departures
          in ( { model | departures = departures }, Cmd.none )

        Err error -> let _ = Debug.log "HTTP error" error in ( model, Cmd.none )

    GotHarbours result ->
      case result of
        Ok harbours ->
            case List.head harbours of
                Just harbour ->
                    ( { model | harbours = harbours, harbour = Just harbour }, Cmd.none )

                Nothing -> ( model, Cmd.none )

        Err error -> let _ = Debug.log "HTTP error" error in ( model, Cmd.none )

    GotTicketRequests result ->
      case result of
        Ok tickets ->
          let _ = Debug.log "tickets" tickets
          in ( { model | ticket_requests = tickets }
             , getTickets model.server_url temporary_developer_customer_id)

        Err error -> let _ = Debug.log "HTTP error" error in ( model, Cmd.none )

subscriptions : Model -> Sub Msg
subscriptions _ = Sub.none

-- VIEW

view_header : Html Msg
view_header =
  div [ class "header" ]
    [ h4 [ class "header-title" ]
      [ text "Læsøfærgen. "
      , span [ class "header-subtitle" ] [ text "Nemt til og fra Læsø" ]
      ]
    ]

view_step : Step -> Step -> String -> Html Msg
view_step current_step step label =
  div
    [ classList [ ( "step", True ), ( "selected", current_step == step ) ]
    , onClick (StepClicked step)
    ]
    [ text label ]

view_separator : Html Msg
view_separator =
  div [ class "step-separator" ] []

type alias Radio_Button_Item = { id : Int, name : String }

view_radio_button :
  (Radio_Button_Item -> msg)
  -> Maybe Radio_Button_Item
  -> Radio_Button_Item
  -> Html msg
view_radio_button to_Msg current item =
  div
    [ classList [ ( "radio-button", True ), ( "selected", current == Just item ) ]
    , onClick (to_Msg item)
    ]
    [ span [ class "radio-button-label" ] [ text item.name ] ]

view_ticket : Int -> Ticket_Response -> Html Msg
view_ticket index ticket =
  div [ class "ticket" ]
    [ div [ class "ticket-label" ] [ text "Person 1" ]
    , div [ class "ticket-divider" ]
      [ div [ class "ticket-divider-dot" ] []
      , div [ class "ticket-divider-line" ] []
      , div [ class "ticket-divider-dot" ] []
      ]
    , div [ class "ticket-fields" ]
      [ input
        [ class "ticket-input"
        , placeholder "Fornavn"
        , required True
        , onBlur (Ticket_Validate Ticket_First_Name)
        , onInput (Ticket_Changed Ticket_First_Name)
        ] []
      , input
        [ class "ticket-input"
        , placeholder "Efternavn"
        , required True
        , onBlur (Ticket_Validate Ticket_Last_Name)
        , onInput (Ticket_Changed Ticket_Last_Name)
        ] []
      , div [ class "ticket-date-row" ]
        [ input
          [ class "ticket-input"
          , type_ "date"
          , required True
          , onBlur (Ticket_Validate Ticket_Date_Of_Birth)
          , onInput (Ticket_Changed Ticket_Date_Of_Birth)
          ] []
        ]
      , div [ class "ticket-price" ]
        [ span [ class "ticket-price-text" ] [ text "-- DKK" ] ]
      ]
    ]

view_step_panel : Model -> Html Msg
view_step_panel model =
  case model.step of
    Departure_From_Step ->
      div [ class "harbour-list" ]
        (List.map
          (\harbour -> view_radio_button Harbour_Selected model.harbour harbour) model.harbours
        )

    Ticket_Step ->
      div [ class "ticket-list" ]
        (List.indexedMap view_ticket model.ticket_responses ++
          [ div
              [ class "create-ticket"
              , onClick Create_Ticket_Clicked
              ]
              [ text "Opret ny billet" ]

          , div
              [ classList
                  [ ( "create-ticket-dropdown", True )
                  , ( "selected", model.is_create_ticket_expanded )
                  ]
              ]
              []
          ]
        )

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
  div [ class "ticket-picker" ]
    [ div [ class "step-selector" ]
      [ view_step model.step Departure_From_Step "Udrejse"
      , view_separator
      , view_step model.step Ticket_Step "Billet"
      , view_separator
      , view_step model.step Departure_Step "Afgang"
      , view_separator
      , div [ class "confirm-wrapper" ]
        [ div [ class "confirm-button", onClick (StepClicked Confirm_Pay_Step) ]
          [ text "Bekræft og betal"
          , div [ class "confirm-icon" ]
            [ svg
              [ Svg.Attributes.width "1rem"
              , Svg.Attributes.height "1rem"
              ]
              [ path
                [ d "M12.136.326A1.5 1.5 0 0 1 14 1.78V3h.5A1.5 1.5 0 0 1 16 4.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 0 13.5v-9a1.5 1.5 0 0 1 1.432-1.499zM5.562 3H13V1.78a.5.5 0 0 0-.621-.484zM1.5 4a.5.5 0 0 0-.5.5v9a.5.5 0 0 0 .5.5h13a.5.5 0 0 0 .5-.5v-9a.5.5 0 0 0-.5-.5z" ]
                []
              ]
            ]
          ]
        ]
      ]
    , div [ class "step-panel" ] [ view_step_panel model ]
    ]

view : Model -> Html Msg
view model =
  div [ class "app" ]
    [ div [ class "app-scroll" ]
      [ view_header
      , view_ticket_picker model
      ]
    ]
