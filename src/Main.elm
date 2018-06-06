port module Main exposing (..)

import Platform exposing (worker)



-- PORTS


port fromHarold : ( String, String ) -> Cmd msg


type HaroldAction
    = Say String
    | SetUserPrompt String
    | Goodbye String


send : HaroldAction -> Cmd Msg
send action =
    let
        pair =
            case action of
                Say message ->
                    ( "SAY", botName ++ message )

                SetUserPrompt name ->
                    ( "SET_USER_PROMPT", name )

                Goodbye message ->
                    ( "GOODBYE", botName ++ message )
    in
    fromHarold pair


port toHarold : (( String, String ) -> msg) -> Sub msg


type UserAction
    = UserReady
    | UserSays String


subscribe : Model -> ( String, String ) -> Msg
subscribe { state } fromUser =
    decodeUserAction fromUser
        |> Maybe.map (makeMsg state)
        |> Maybe.withDefault NoOp


decodeUserAction : ( String, String ) -> Maybe UserAction
decodeUserAction ( action, payload ) =
    case action of
        "READY" ->
            Just <| UserReady

        "SAY" ->
            Just <| UserSays payload

        _ ->
            Nothing


makeMsg : State -> UserAction -> Msg
makeMsg state action =
    case ( action, state ) of
        ( UserReady, _ ) ->
            WakeUp

        ( _, Sleeping ) ->
            NoOp

        ( UserSays userMessage, currentState ) ->
            if isGoodbye userMessage then
                SayGoodbye

            else
                case currentState of
                    Sleeping ->
                        NoOp

                    Ready ->
                        RespondTo userMessage

                    AskingFor userInfo ->
                        Remember userInfo userMessage


isGoodbye : String -> Bool
isGoodbye =
    String.toLower
        >> (\message ->
                List.member message
                    [ "exit"
                    , "bye"
                    , "goodbye"
                    , "see ya"
                    , "adios"
                    ]
           )



-- PROGRAM


botName : String
botName =
    "\u{001B}[36mHarold:\u{001B}[0m "


userPrompt : String -> String
userPrompt name =
    "\u{001B}[32m" ++ name ++ ":\u{001B}[0m "


type alias Model =
    { state : State
    , user : User
    }


type State
    = Sleeping
    | Ready
    | AskingFor UserInfo


type UserInfo
    = Name


type Msg
    = NoOp
    | WakeUp
    | RespondTo String
    | RespondWith String
    | SayGoodbye
    | Remember UserInfo String
    | HandleUnkownAction String


type alias User =
    { name : Maybe String
    }


type alias Flags =
    ()


main : Program Flags Model Msg
main =
    worker
        { init = init
        , update = update
        , subscriptions = subscriptions
        }


init : Flags -> ( Model, Cmd Msg )
init _ =
    ( Model
        Sleeping
        (User Nothing)
    , Cmd.none
    )


update : Msg -> Model -> ( Model, Cmd Msg )
update msg model =
    case msg of
        NoOp ->
            ( model, Cmd.none )

        WakeUp ->
            ( { model | state = Ready }, say "Hey, there!" )

        RespondTo userMessage ->
            respond model userMessage

        RespondWith message ->
            ( model, say message )

        Remember userInfo payload ->
            case ( userInfo, payload ) of
                ( Name, name ) ->
                    ( { model
                        | user = setName name model.user
                        , state = Ready
                      }
                    , Cmd.batch
                        [ respondTo name model ""
                        , send <| SetUserPrompt (userPrompt name)
                        ]
                    )

        SayGoodbye ->
            ( model
            , send <| Goodbye "See ya!"
            )

        HandleUnkownAction action ->
            ( model, say "Sorry, I don't understand." )


setName : String -> User -> User
setName name user =
    { user | name = Just name }


respond : Model -> String -> ( Model, Cmd Msg )
respond model userMessage =
    case model.user.name of
        Just name ->
            ( model
            , respondTo name model userMessage
            )

        Nothing ->
            ( { model | state = AskingFor Name }
            , say "Hey! What's your name?"
            )


respondTo : String -> Model -> String -> Cmd Msg
respondTo name model userMessage =
    case model.state of
        AskingFor Name ->
            say <| "Hello, " ++ name ++ "!"

        _ ->
            say "We had a nice conversation."


say : String -> Cmd Msg
say message =
    send (Say message)


subscriptions : Model -> Sub Msg
subscriptions model =
    toHarold (subscribe model)
