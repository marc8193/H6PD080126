module Main exposing (..)

import Browser
import Date
import Dict exposing (Dict)
import Html exposing (Html, div, h4, p, span, text, input)
import Html.Attributes exposing (class, classList, style, placeholder, required, value, type_)
import Html.Events exposing (onClick, onInput, onMouseLeave)
import Http
import Json.Decode as Decode
import Svg exposing (path, svg)
import Svg.Attributes exposing (d, fill, viewBox)
import Task
import Time
import Time.Extra as TimeExtra
import TimeZone

-- MAIN

main = Browser.element
  { init = init
  , update = update
  , subscriptions = \_ -> Sub.none
  , view = view
  }

-- MODEL

type alias Flags =
  { server_url : String
  }

type Step
  = Departure_From_Step
  | Ticket_Step
  | Departure_Step
  | Departure_Day_Step (List Departure)
  | Confirm_Pay_Step

type Dropdown = Create_Ticket_Dropdown | Vehicle_Variant_Dropdown Int

type alias Harbour =
  { id : Int
  , name : String
  }

type alias Capacity =
  { id : Int
  , maximum : Int
  , category : String
  }

type alias Ferry =
  { id : Int
  , name : String
  , capacities : List Capacity
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
  , zone : Time.Zone
  , start : Time.Posix
  , canceled : Bool
  }

type alias Person_Details =
  { firstname : String
  , lastname : String
  , birthday : String
  }

type Variant = Car | Truck | Bicycle
type alias Vehicle_Details =
  { variant : Variant
  , identification : String
  }

type Category
  = Person Person_Details
  | Pet
  | Breakfast
  | Firstclass
  | Vehicle Vehicle_Details

type alias Ticket =
  { id : Int
  , departure : Departure
  , user : User
  , category : Category
  }

type alias Model =
  { flags : Flags
  , today : Time.Posix
  , system_zone : Time.Zone
  , step : Step
  , dropdown : Maybe Dropdown
  , user : User
  , harbours : List Harbour
  , tickets : Dict Int Ticket
  , departures : List Departure
  }

nil_user : User
nil_user =
  { id = -1
  , name = ""
  , email = ""
  , role = ""
  }

nil_ticket : Ticket
nil_ticket =
  { id = -1
  , departure =
      { id = -1
      , ferry = { id = -1, name = "", capacities = [] }
      , harbour = { id = -1, name = "" }
      , user = nil_user
      , zone = Time.utc
      , start = Time.millisToPosix 0
      , canceled = False
      }

  , user = nil_user
  , category = Person (Person_Details "" "" "")
  }

init : Flags -> ( Model, Cmd Msg )
init flags =
  ( { flags = { server_url = flags.server_url }
    , today = Time.millisToPosix 0
    , system_zone = TimeZone.europe__berlin ()
    , step = Departure_From_Step
    , dropdown = Nothing
    , user = nil_user
    , harbours = []
    , tickets = Dict.singleton 0 nil_ticket
    , departures = []
    }
  , Cmd.batch
    [ Task.perform Got_Time Time.now
    , get_harbours flags.server_url
    , get_users flags.server_url 2
    ]
  )

categories : List Category
categories =
  [ Person { firstname = "", lastname = "", birthday = "" }
  , Pet
  , Breakfast
  , Firstclass
  , Vehicle { variant = Car, identification = "" }
  ]

category_to_string : Category -> String
category_to_string category =
  case category of
    Person _ -> "Person"
    Pet -> "Kæledyr"
    Breakfast -> "Morgenmad"
    Firstclass -> "Førsteklasse"
    Vehicle _ -> "Køretøj"

variants : List Variant
variants = [ Car, Truck, Bicycle ]
variant_to_string : Variant -> String
variant_to_string variant =
  case variant of
    Car -> "Bil"
    Truck -> "Lastbil"
    Bicycle -> "Cykel"

-- API

ferries_capacities_decoder : Decode.Decoder Capacity
ferries_capacities_decoder =
  Decode.map3
    Capacity
    (Decode.field "id" Decode.int)
    (Decode.field "maximum" Decode.int)
    (Decode.field "category" Decode.string)


ferries_decoder : Decode.Decoder Ferry
ferries_decoder =
  Decode.map3
    Ferry
    (Decode.field "id" Decode.int)
    (Decode.field "name" Decode.string)
    (Decode.field "capacities" (Decode.list ferries_capacities_decoder))

harbours_decoder : Decode.Decoder Harbour
harbours_decoder =
  Decode.map2
    Harbour
    (Decode.field "id" Decode.int)
    (Decode.field "name" Decode.string)

users_decoder : Decode.Decoder User
users_decoder =
  Decode.map4
    User
    (Decode.field "id" Decode.int)
    (Decode.field "name" Decode.string)
    (Decode.field "email" Decode.string)
    (Decode.field "role" Decode.string)

zone_decoder : Decode.Decoder Time.Zone
zone_decoder =
  Decode.string
    |> Decode.andThen
      (\name ->
        case Dict.get name TimeZone.zones of
          Just zone -> Decode.succeed (zone ())
          Nothing -> Decode.fail ("Unknown time zone: " ++ name)
      )

departures_decoder : Decode.Decoder Departure
departures_decoder =
  Decode.map7
    Departure
    (Decode.field "id" Decode.int)
    (Decode.field "ferry" ferries_decoder)
    (Decode.field "harbour" harbours_decoder)
    (Decode.field "user" users_decoder)
    (Decode.field "zone" zone_decoder)
    (Decode.field "start" (Decode.map Time.millisToPosix Decode.int))
    (Decode.field "canceled" Decode.bool)

variant_decoder : Decode.Decoder Variant
variant_decoder =
  Decode.string
    |> Decode.andThen
      (\variant ->
        case variant of
          "car" -> Decode.succeed Car
          "truck" -> Decode.succeed Truck
          "bicycle" -> Decode.succeed Bicycle
          _ -> Decode.fail ("Unknown variant: " ++ variant)
      )

category_decoder : Decode.Decoder Category
category_decoder =
  Decode.field
    "category"
    Decode.string
    |> Decode.andThen
      (\category ->
        case category of
          "person" ->
            Decode.map
              Person
              (Decode.map3
                Person_Details
                (Decode.at [ "person", "firstname" ] Decode.string)
                (Decode.at [ "person", "lastname" ] Decode.string)
                (Decode.at [ "person", "birthday" ] Decode.string)
              )

          "pet" ->
            Decode.succeed Pet

          "breakfast" ->
            Decode.succeed Breakfast

          "firstclass" ->
            Decode.succeed Firstclass

          "vehicle" ->
            Decode.map
              Vehicle
              (Decode.map2
                Vehicle_Details
                (Decode.at [ "vehicle", "variant" ] variant_decoder)
                (Decode.at [ "vehicle", "identification" ] Decode.string)
              )

          _ -> Decode.fail ("Unknown category: " ++ category)
      )

tickets_decoder : Decode.Decoder Ticket
tickets_decoder =
  Decode.map4
    Ticket
    (Decode.field "id" Decode.int)
    (Decode.field "departure" departures_decoder)
    (Decode.field "user" users_decoder)
    category_decoder


get_users : String -> Int -> Cmd Msg
get_users server_url id =
  Http.get
  { url = server_url ++ "/users?id=" ++ String.fromInt id
  , expect = Http.expectJson Got_Users users_decoder
  }

get_departures : String -> Maybe Int -> Cmd Msg
get_departures server_url harbour_id =
  case harbour_id of
    Just id ->
      Http.get
        { url = server_url ++ "/departures?harbour_id=" ++ String.fromInt id
        , expect = Http.expectJson Got_Departures (Decode.list departures_decoder)
        }

    Nothing -> Cmd.none

get_harbours : String -> Cmd Msg
get_harbours server_url =
  Http.get
  { url = server_url ++ "/harbours"
  , expect = Http.expectJson Got_Harbours (Decode.list harbours_decoder)
  }

get_tickets : String -> Int -> Cmd Msg
get_tickets server_url user_id =
  Http.get
  { url = server_url ++ "/tickets?user_id=" ++ String.fromInt user_id
  , expect = Http.expectJson Got_Ticket (Decode.list tickets_decoder)
  }

-- UPDATE

type Ticket_Field
  = Ticket_Person_Firstname
  | Ticket_Person_Lastname
  | Ticket_Person_Date_Of_Birth
  | Ticket_Vehicle_Identification

type Msg
  = Step_Clicked Step
  | Step_Panel_Leaved
  | Dropdown_Clicked Dropdown
  | Got_Time Time.Posix
  | Got_Users (Result Http.Error User)
  -- Harbour
  | Got_Harbours (Result Http.Error (List Harbour))
  | Harbour_Selected Harbour
  -- Ticket
  | Got_Ticket (Result Http.Error (List Ticket))
  | Create_Ticket_Selected Category
  | Vehicle_Ticket_Variant_Selected Int Variant
  | Ticket_Changed Int Ticket_Field String
  -- Departure
  | Got_Departures (Result Http.Error (List Departure))
  | Departure_Clicked (List Departure)

update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
  case msg of
    Step_Clicked step ->
      case step of
          Departure_Step ->
            case model.tickets |> Dict.values |> List.head of
              Just ticket ->
                let
                  _ = Debug.log "Departures" model.departures
                in
                  ( { model | step = step }
                  , get_departures model.flags.server_url (Just ticket.departure.harbour.id) )

              Nothing -> ( { model | step = step }, Cmd.none )

          Ticket_Step ->
            let _ = Debug.log "Tickets" model.tickets in ( { model | step = step }, Cmd.none )

          _ -> ( { model | step = step }, Cmd.none )

    Step_Panel_Leaved -> ( { model | dropdown = Nothing }, Cmd.none )

    Dropdown_Clicked dropdown ->
      ( { model | dropdown = if model.dropdown == Just dropdown then Nothing else Just dropdown }
      , Cmd.none
      )

    Got_Time time -> ( { model | today = time }, Cmd.none )

    Got_Users result ->
      case result of
        Ok user ->
          let tickets = Dict.map (\_ ticket -> { ticket | user = user }) model.tickets
          in ( { model | user = user, tickets = tickets }, Cmd.none )

        Err error -> let _ = Debug.log "Users - HTTP error" error in ( model, Cmd.none )

    Got_Harbours result ->
      case result of
        Ok harbours ->
            case List.head harbours of
                Just harbour ->
                    ( { model | harbours = harbours }, Cmd.none )

                Nothing -> ( model, Cmd.none )

        Err error -> let _ = Debug.log "Harbours - HTTP error" error in ( model, Cmd.none )

    Harbour_Selected harbour ->
      ( { model
          | tickets =
            Dict.map
              (\_ ticket ->
                let departure = ticket.departure
                in { ticket | departure = { departure | harbour = harbour } }
              ) model.tickets

          , step = Ticket_Step
        }
      , Cmd.none
      )

    Got_Ticket result ->
      case result of
        Ok tickets ->
          let ticket_dict = tickets |> List.indexedMap Tuple.pair |> Dict.fromList
          in ( { model | tickets = ticket_dict }, Cmd.none )

        Err error -> ( model, Cmd.none )

    Create_Ticket_Selected category ->
      let
        base_ticket = model.tickets |> Dict.get 0 |> Maybe.withDefault nil_ticket
        ticket = { base_ticket | category = category }
        ticket_id = Dict.size model.tickets
        tickets = Dict.insert ticket_id ticket model.tickets
      in
        ( { model | dropdown = Nothing, tickets = tickets }, Cmd.none )

    Vehicle_Ticket_Variant_Selected ticket_id variant ->
      let
        tickets =
          Dict.update
            ticket_id
            (Maybe.map
              (\ticket ->
                { ticket
                  | category =
                      case ticket.category of
                        Vehicle vehicle -> Vehicle { vehicle | variant = variant }
                        category -> category
                }
              )
            )
            model.tickets
      in
        ( { model | dropdown = Nothing, tickets = tickets }, Cmd.none )

    Ticket_Changed ticket_id field value ->
      let
        tickets =
          Dict.update ticket_id
            (Maybe.map
              (\ticket ->
                { ticket
                  | category =
                      case ( field, ticket.category ) of
                        ( Ticket_Person_Firstname, Person person ) ->
                          Person { person | firstname = value }

                        ( Ticket_Person_Lastname, Person person ) ->
                          Person { person | lastname = value }

                        ( Ticket_Person_Date_Of_Birth, Person person ) ->
                          Person { person | birthday = value }

                        ( Ticket_Vehicle_Identification, Vehicle vehicle ) ->
                          Vehicle { vehicle | identification = value }

                        _ -> ticket.category
                }
              )
            )
            model.tickets
      in
      ( { model | tickets = tickets }, Cmd.none )

    Got_Departures result ->
      case result of
        Ok departures -> ( { model | departures = departures }, Cmd.none )
        Err error -> let _ = Debug.log "Departures - HTTP error" error in ( model, Cmd.none )

    Departure_Clicked selected_departures ->
      ( { model | step = Departure_Day_Step selected_departures }, Cmd.none )

-- VIEW WIDGETS

type alias Radio_Button_Item = { id : Int, name : String }

view_radio_button :
  (Radio_Button_Item -> msg)
  -> Maybe Radio_Button_Item
  -> Radio_Button_Item
  -> Html msg

view_radio_button to_msg current item =
  div
  [ classList [ ( "radio-button", True ), ( "selected", current == Just item ) ]
  , onClick (to_msg item)
  ]
  [ span [ class "radio-button-label" ] [ text item.name ] ]

view_dropdown : msg -> Dropdown -> String -> Maybe Dropdown -> (a -> Html msg) -> List a -> Html msg
view_dropdown msg dropdown label selected view_option options =
  div [ class "dropdown-container" ]
  [ span [ class "dropdown-text", onClick msg ] [ text label ]
  , div
    [ classList
      [ ( "dropdown", True ), ( "selected", selected == Just dropdown ) ]
    ]
    (List.map view_option options)
  ]

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
  , onClick (Step_Clicked step)
  ]
  [ text label ]

view_separator : Html Msg
view_separator = div [ class "step-separator" ] []

view_person_ticket_fields : Int -> Ticket -> Html Msg
view_person_ticket_fields ticket_id ticket =
  case ticket.category of
    Person person ->
      div [ class "ticket-fields" ]
        [ input
          [ class "ticket-input"
          , placeholder "Fornavn"
          , required True
          , value person.firstname
          , onInput (Ticket_Changed ticket_id Ticket_Person_Firstname)
          ] []
        , input
          [ class "ticket-input"
          , placeholder "Efternavn"
          , value person.lastname
          , required True
          , onInput (Ticket_Changed ticket_id Ticket_Person_Lastname)
          ] []
        , input
          [ class "ticket-input"
          , type_ "date"
          , value person.birthday
          , required True
          , onInput (Ticket_Changed ticket_id Ticket_Person_Date_Of_Birth)
          ] []
        ]

    _ -> text ""

resolve_variant : Int -> Variant -> Html Msg
resolve_variant ticket_id variant =
  div [ class "dropdown-option", onClick (Vehicle_Ticket_Variant_Selected ticket_id variant) ]
  ((case variant of
    Car ->
      [ svg [ Svg.Attributes.width "1rem", Svg.Attributes.height "1rem" ]
        [ path [ d "M4 9a1 1 0 1 1-2 0 1 1 0 0 1 2 0m10 0a1 1 0 1 1-2 0 1 1 0 0 1 2 0M6 8a1 1 0 0 0 0 2h4a1 1 0 1 0 0-2zM4.862 4.276 3.906 6.19a.51.51 0 0 0 .497.731c.91-.073 2.35-.17 3.597-.17s2.688.097 3.597.17a.51.51 0 0 0 .497-.731l-.956-1.913A.5.5 0 0 0 10.691 4H5.309a.5.5 0 0 0-.447.276" ] []
        , path [ d "M2.52 3.515A2.5 2.5 0 0 1 4.82 2h6.362c1 0 1.904.596 2.298 1.515l.792 1.848c.075.175.21.319.38.404.5.25.855.715.965 1.262l.335 1.679q.05.242.049.49v.413c0 .814-.39 1.543-1 1.997V13.5a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1-.5-.5v-1.338c-1.292.048-2.745.088-4 .088s-2.708-.04-4-.088V13.5a.5.5 0 0 1-.5.5h-2a.5.5 0 0 1-.5-.5v-1.892c-.61-.454-1-1.183-1-1.997v-.413a2.5 2.5 0 0 1 .049-.49l.335-1.68c.11-.546.465-1.012.964-1.261a.8.8 0 0 0 .381-.404l.792-1.848ZM4.82 3a1.5 1.5 0 0 0-1.379.91l-.792 1.847a1.8 1.8 0 0 1-.853.904.8.8 0 0 0-.43.564L1.03 8.904a1.5 1.5 0 0 0-.03.294v.413c0 .796.62 1.448 1.408 1.484 1.555.07 3.786.155 5.592.155s4.037-.084 5.592-.155A1.48 1.48 0 0 0 15 9.611v-.413q0-.148-.03-.294l-.335-1.68a.8.8 0 0 0-.43-.563 1.8 1.8 0 0 1-.853-.904l-.792-1.848A1.5 1.5 0 0 0 11.18 3z" ] []
        ]
      ]

    Truck ->
      [ svg [ Svg.Attributes.width "1rem", Svg.Attributes.height "1rem" ]
        [ path [ d "M0 3.5A1.5 1.5 0 0 1 1.5 2h9A1.5 1.5 0 0 1 12 3.5V5h1.02a1.5 1.5 0 0 1 1.17.563l1.481 1.85a1.5 1.5 0 0 1 .329.938V10.5a1.5 1.5 0 0 1-1.5 1.5H14a2 2 0 1 1-4 0H5a2 2 0 1 1-3.998-.085A1.5 1.5 0 0 1 0 10.5zm1.294 7.456A2 2 0 0 1 4.732 11h5.536a2 2 0 0 1 .732-.732V3.5a.5.5 0 0 0-.5-.5h-9a.5.5 0 0 0-.5.5v7a.5.5 0 0 0 .294.456M12 10a2 2 0 0 1 1.732 1h.768a.5.5 0 0 0 .5-.5V8.35a.5.5 0 0 0-.11-.312l-1.48-1.85A.5.5 0 0 0 13.02 6H12zm-9 1a1 1 0 1 0 0 2 1 1 0 0 0 0-2m9 0a1 1 0 1 0 0 2 1 1 0 0 0 0-2" ] []
        ]
      ]

    Bicycle ->
      [ svg [ Svg.Attributes.width "1rem", Svg.Attributes.height "1rem" ]
        [ path [ d "M4 4.5a.5.5 0 0 1 .5-.5H6a.5.5 0 0 1 0 1v.5h4.14l.386-1.158A.5.5 0 0 1 11 4h1a.5.5 0 0 1 0 1h-.64l-.311.935.807 1.29a3 3 0 1 1-.848.53l-.508-.812-2.076 3.322A.5.5 0 0 1 8 10.5H5.959a3 3 0 1 1-1.815-3.274L5 5.856V5h-.5a.5.5 0 0 1-.5-.5m1.5 2.443-.508.814c.5.444.85 1.054.967 1.743h1.139zM8 9.057 9.598 6.5H6.402zM4.937 9.5a2 2 0 0 0-.487-.877l-.548.877zM3.603 8.092A2 2 0 1 0 4.937 10.5H3a.5.5 0 0 1-.424-.765zm7.947.53a2 2 0 1 0 .848-.53l1.026 1.643a.5.5 0 1 1-.848.53z" ] []
        ]
      ]
  ) ++
    [ span [ class "dropdown-option-text" ] [ text (variant_to_string variant) ] ]
  )

view_vehicle_ticket_fields : Model -> Int -> Ticket -> Html Msg
view_vehicle_ticket_fields model ticket_id ticket =
  case ticket.category of
    Vehicle vehicle ->
      div [ class "ticket-fields" ]
        [ div [ class "select-variant" ]
          [ view_dropdown
              (Dropdown_Clicked (Vehicle_Variant_Dropdown ticket_id))
              (Vehicle_Variant_Dropdown ticket_id)
              (variant_to_string vehicle.variant)
              model.dropdown
              (resolve_variant ticket_id)
              variants
          ]
        , let
            input_placeholder =
              case vehicle.variant of
                Car -> "Nummerplade"
                Truck -> "Nummerplade"
                Bicycle -> "Stelnummer"
          in
          input
            [ class "ticket-input"
            , placeholder input_placeholder
            , value vehicle.identification
            , required True
            , onInput (Ticket_Changed ticket_id Ticket_Vehicle_Identification)
            ] []
        ]

    _ -> text ""

view_ticket : Model -> Int -> Ticket -> Html Msg
view_ticket model ticket_id ticket =
  div [ class "ticket" ]
  [ div [ class "ticket-label" ] [ text (category_to_string ticket.category) ]
  , div [ class "ticket-divider" ]
    [ div [ class "ticket-divider-dot" ] []
    , div [ class "ticket-divider-line" ] []
    , div [ class "ticket-divider-dot" ] []
    ]
  , case ticket.category of
      Person _ -> view_person_ticket_fields ticket_id ticket
      Pet -> div [] []
      Breakfast -> div [] []
      Firstclass -> div [] []
      Vehicle _ -> view_vehicle_ticket_fields model ticket_id ticket
  , div [ class "ticket-price" ] [ span [ class "ticket-price-text" ] [ text "-- DKK" ] ]
  ]

resolve_category : Category -> Html Msg
resolve_category category =
  div [ class "dropdown-option", onClick (Create_Ticket_Selected category) ]
  ((case category of
    Person _ ->
      [ svg [ Svg.Attributes.width "1rem", Svg.Attributes.height "1rem" ]
        [ path [ d "M8 8a3 3 0 1 0 0-6 3 3 0 0 0 0 6m2-3a2 2 0 1 1-4 0 2 2 0 0 1 4 0m4 8c0 1-1 1-1 1H3s-1 0-1-1 1-4 6-4 6 3 6 4m-1-.004c-.001-.246-.154-.986-.832-1.664C11.516 10.68 10.289 10 8 10s-3.516.68-4.168 1.332c-.678.678-.83 1.418-.832 1.664z" ] []
        ]
      ]

    Pet ->
      [ svg [ Svg.Attributes.width "1rem", Svg.Attributes.height "1rem" ]
        [ path [ d "M8 7.982C9.664 6.309 13.825 9.236 8 13 2.175 9.236 6.336 6.31 8 7.9822" ] []
        , path [ d "M3.75 0a1 1 0 0 0-.8.4L.1 4.2a.5.5 0 0 0-.1.3V15a1 1 0 0 0 1 1h14a1 1 0 0 0 1-1V4.5a.5.5 0 0 0-.1-.3L13.05.4a1 1 0 0 0-.8-.4zm0 1H7.5v3h-6zM8.5 4V1h3.75l2.25 3zM15 5v10H1V5z" ] []
        ]
      ]

    Breakfast ->
      [ svg [ Svg.Attributes.width "1rem", Svg.Attributes.height "1rem" ]
        [ path [ d "M8 11a3 3 0 1 0 0-6 3 3 0 0 0 0 6" ] []
        , path [ d "M13.997 5.17a5 5 0 0 0-8.101-4.09A5 5 0 0 0 1.28 9.342a5 5 0 0 0 8.336 5.109 3.5 3.5 0 0 0 5.201-4.065 3.001 3.001 0 0 0-.822-5.216zm-1-.034a1 1 0 0 0 .668.977 2.001 2.001 0 0 1 .547 3.478 1 1 0 0 0-.341 1.113 2.5 2.5 0 0 1-3.715 2.905 1 1 0 0 0-1.262.152 4 4 0 0 1-6.67-4.087 1 1 0 0 0-.2-1 4 4 0 0 1 3.693-6.61 1 1 0 0 0 .8-.2 4 4 0 0 1 6.48 3.273z" ] []
        ]
      ]

    Firstclass ->
      [ svg [ Svg.Attributes.width "1rem", Svg.Attributes.height "1rem" ]
        [ path [ d "M6.5 1A1.5 1.5 0 0 0 5 2.5V3H1.5A1.5 1.5 0 0 0 0 4.5v8A1.5 1.5 0 0 0 1.5 14h13a1.5 1.5 0 0 0 1.5-1.5v-8A1.5 1.5 0 0 0 14.5 3H11v-.5A1.5 1.5 0 0 0 9.5 1zm0 1h3a.5.5 0 0 1 .5.5V3H6v-.5a.5.5 0 0 1 .5-.5m1.886 6.914L15 7.151V12.5a.5.5 0 0 1-.5.5h-13a.5.5 0 0 1-.5-.5V7.15l6.614 1.764a1.5 1.5 0 0 0 .772 0M1.5 4h13a.5.5 0 0 1 .5.5v1.616L8.129 7.948a.5.5 0 0 1-.258 0L1 6.116V4.5a.5.5 0 0 1 .5-.5" ] []
        ]
      ]

    Vehicle _ ->
      [ svg [ Svg.Attributes.width "1rem", Svg.Attributes.height "1rem" ]
        [ path [ d "M0 3.5A1.5 1.5 0 0 1 1.5 2h9A1.5 1.5 0 0 1 12 3.5V5h1.02a1.5 1.5 0 0 1 1.17.563l1.481 1.85a1.5 1.5 0 0 1 .329.938V10.5a1.5 1.5 0 0 1-1.5 1.5H14a2 2 0 1 1-4 0H5a2 2 0 1 1-3.998-.085A1.5 1.5 0 0 1 0 10.5zm1.294 7.456A2 2 0 0 1 4.732 11h5.536a2 2 0 0 1 .732-.732V3.5a.5.5 0 0 0-.5-.5h-9a.5.5 0 0 0-.5.5v7a.5.5 0 0 0 .294.456M12 10a2 2 0 0 1 1.732 1h.768a.5.5 0 0 0 .5-.5V8.35a.5.5 0 0 0-.11-.312l-1.48-1.85A.5.5 0 0 0 13.02 6H12zm-9 1a1 1 0 1 0 0 2 1 1 0 0 0 0-2m9 0a1 1 0 1 0 0 2 1 1 0 0 0 0-2" ] []
        ]
      ]
  ) ++
    [ span [ class "dropdown-option-text" ] [ text (category_to_string category) ] ]
  )

weekday_to_number : Time.Weekday -> Int
weekday_to_number weekday =
  case weekday of
    Time.Mon -> 0
    Time.Tue -> 1
    Time.Wed -> 2
    Time.Thu -> 3
    Time.Fri -> 4
    Time.Sat -> 5
    Time.Sun -> 6

week_start : Time.Zone -> Time.Posix -> Time.Posix
week_start zone start =
  TimeExtra.add TimeExtra.Day (-(weekday_to_number (Time.toWeekday zone start))) zone start

week_row : Time.Zone -> Time.Posix -> Time.Posix -> Int
week_row zone today departure =
  let
    current_week = week_start zone today
    departure_week = week_start zone departure
  in
  TimeExtra.diff TimeExtra.Week zone current_week departure_week + 1

lastest_week_row : Time.Zone -> Time.Posix -> List Departure -> Int
lastest_week_row zone today departures =
  departures
    |> List.map (\departure -> week_row zone today departure.start)
    |> List.maximum
    |> Maybe.withDefault 1

view_week_number : Time.Zone -> Time.Posix -> Int -> Html Msg
view_week_number zone today row =
  let
    date = TimeExtra.add TimeExtra.Week (row - 1) zone today
    week = Date.fromPosix zone date |> Date.weekNumber
  in
  div
    [ class "week-number-departure-item"
    , style "grid-column" "1"
    , style "grid-row" (String.fromInt row)
    ]
    [ text (String.fromInt week) ]

view_departures : Time.Zone -> Time.Posix -> List Departure -> Html Msg
view_departures zone today departures =
  case List.head departures of
    Just departure ->
      let
        weekday = Time.toWeekday departure.zone departure.start
        column = weekday_to_number weekday + 2
        row = week_row zone today departure.start
        date = Date.fromPosix departure.zone departure.start
      in
        if row < 1 then
          text ""
        else
          div
            [ class "departure-item"
            , style "grid-column" (String.fromInt column)
            , style "grid-row" (String.fromInt row)
            , onClick (Departure_Clicked departures)
            ]
            [ div [] [ text (String.fromInt (Date.day date)) ]
            , div [] [ text (Date.format "MMMM" date) ]
            ]

    Nothing ->
      text ""

group_departures_by_day : List Departure -> List (List Departure)
group_departures_by_day departures =
  let
    departures_sorted_by_start_time =
      List.sortBy (\departure -> Time.posixToMillis departure.start) departures
  in
    List.foldl
      (\departure grouped_departures ->
        case grouped_departures of
          -- If grouped_departures is not empty
          previous_group :: remaining_groups ->
            case List.head previous_group of
              -- Get head of previous_group == previous_departure if not Nothing
              Just previous_departure ->
                let
                  current_date = Date.fromPosix departure.zone departure.start
                  previous_date = Date.fromPosix previous_departure.zone previous_departure.start
                in
                  if current_date == previous_date then
                    -- Prepend departure to the current day group
                    (departure :: previous_group) :: remaining_groups
                  else
                    -- Start a new day group and prepend it to grouped_departures
                    [ departure ] :: grouped_departures

              -- This should not normally happen because empty groups are never created, but all paths needs to be defined
              Nothing -> [ departure ] :: remaining_groups

          -- Create the initial List (List Departure) for the first departure
          [] -> [ [ departure ] ]
      )
      []
      departures_sorted_by_start_time

view_departure_day : Time.Zone -> List Departure -> Html Msg
view_departure_day zone departures = div [] []

view_step_panel : Model -> Html Msg
view_step_panel model =
  case model.step of
    Departure_From_Step ->
      div [ class "harbour-list" ]
        (List.map
          (\harbour ->
            view_radio_button
              Harbour_Selected
              (model.tickets
                |> Dict.values
                |> List.head
                |> Maybe.map (\ticket -> ticket.departure.harbour)
              )
              harbour
          )
          model.harbours
        )

    Ticket_Step ->
      div [ class "ticket-list" ]
      (Dict.foldr (\ticket_id ticket views -> view_ticket model ticket_id ticket :: views)
      []
      model.tickets
        ++
        [ div [ class "create-ticket" ]
          [ view_dropdown
              (Dropdown_Clicked Create_Ticket_Dropdown)
              Create_Ticket_Dropdown
              "Opret ny billet"
              model.dropdown
              resolve_category
              categories
          ]
        ]
      )

    Departure_Step ->
      div [ class "departure" ]
      (List.map
        (view_week_number model.system_zone model.today)
        (List.range 1 (lastest_week_row model.system_zone model.today model.departures))
        ++ List.map
             (view_departures model.system_zone model.today)
             (group_departures_by_day model.departures)
      )

    Departure_Day_Step departures ->
      div [ class "departure-day" ] [ view_departure_day model.system_zone departures ]

    Confirm_Pay_Step -> div [] [ text "Bekræft og betal" ]

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
        [ div [ class "confirm-button", onClick (Step_Clicked Confirm_Pay_Step) ]
          [ text "Bekræft og betal"
          , div [ class "confirm-icon" ]
            [ svg [ Svg.Attributes.width "1rem", Svg.Attributes.height "1rem" ]
              [ path [ d "M12.136.326A1.5 1.5 0 0 1 14 1.78V3h.5A1.5 1.5 0 0 1 16 4.5v9a1.5 1.5 0 0 1-1.5 1.5h-13A1.5 1.5 0 0 1 0 13.5v-9a1.5 1.5 0 0 1 1.432-1.499zM5.562 3H13V1.78a.5.5 0 0 0-.621-.484zM1.5 4a.5.5 0 0 0-.5.5v9a.5.5 0 0 0 .5.5h13a.5.5 0 0 0 .5-.5v-9a.5.5 0 0 0-.5-.5z" ] []
              ]
            ]
          ]
        ]
      ]
    , div [ class "step-panel", onMouseLeave Step_Panel_Leaved ] [ view_step_panel model ]
    ]

view : Model -> Html Msg
view model =  div [ class "app" ] [ div [ class "app-scroll" ] [ view_header, view_ticket_picker model ] ]