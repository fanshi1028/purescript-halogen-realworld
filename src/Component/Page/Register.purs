module Conduit.Component.Page.Register where

import Prelude

import Conduit.Api.Request (AuthUser)
import Conduit.Capability.ManageResource (class ManageResource, register)
import Conduit.Capability.Navigate (class Navigate, navigate)
import Conduit.Component.HTML.Header (header)
import Conduit.Component.HTML.Utils (css, safeHref)
import Conduit.Data.Email (Email)
import Conduit.Data.Route (Route(..))
import Conduit.Data.Username (Username)
import Conduit.Form.Field as Field
import Conduit.Form.Validation as V
import Data.Maybe (Maybe(..), isJust)
import Data.Newtype (class Newtype)
import Data.Traversable (traverse_)
import Effect.Aff.Class (class MonadAff)
import Formless as F
import Formless as Formless
import Halogen as H
import Halogen.HTML as HH
import Halogen.HTML.Events as HE
import Halogen.HTML.Properties as HP

data Query a
  = Initialize a
  | HandleForm (F.Message' RegisterForm) a

type State =
  { authUser :: Maybe AuthUser
  , registerError :: Maybe (Array String)
  }

type Input = 
  { authUser :: Maybe AuthUser }

type ChildQuery m = F.Query' RegisterForm m
type ChildSlot = Unit

component 
  :: forall m
   . MonadAff m 
  => Navigate m
  => ManageResource m
  => H.Component HH.HTML Query Input Void m
component = 
  H.lifecycleParentComponent
    { initialState: \{ authUser } -> { authUser, registerError: Nothing }
    , render
    , eval
    , receiver: const Nothing
    , initializer: Just $ H.action Initialize
    , finalizer: Nothing
    }
  where
  render :: State -> H.ParentHTML Query (ChildQuery m) ChildSlot m
  render { registerError } =
    container
      [ HH.h1
        [ css "text-xs-center"]
        [ HH.text "Sign Up" ]
      , HH.p
        [ css "text-xs-center" ]
        [ HH.a 
          [ safeHref Login ]
          [ HH.text "Already have an account?" ]
        ]
      , HH.slot unit Formless.component 
          { initialInputs: F.mkInputFields formProxy
          , validators 
          , render: renderFormless 
          } 
          (HE.input HandleForm)
      ]
    where
    container html =
      HH.div_
        [ header Nothing Register
        , HH.div
          [ css "auth-page" ]
          [ HH.div
              [ css "container page" ]
              [ HH.div
              [ css "row" ]
              [ HH.div
                  [ css "col-md-6 offset-md-3 col-xs12" ]
                  html
              ]
              ]
          ]
        ]

  eval :: Query ~> H.ParentDSL State Query (ChildQuery m) Unit Void m
  eval = case _ of
    Initialize a -> do
      st <- H.get
      when (isJust st.authUser) (navigate Home)
      pure a

    HandleForm msg a -> case msg of
      F.Submitted formOutputs -> do 
        eitherAuthUser <- register $ F.unwrapOutputFields formOutputs
        traverse_ (\_ -> navigate Home) eitherAuthUser
        pure a
      _ -> pure a


-----
-- Form

newtype RegisterForm r f = RegisterForm (r
  ( username :: f V.FormError String Username
  , email :: f V.FormError String Email
  , password :: f V.FormError String String
  ))

derive instance newtypeRegisterForm :: Newtype (RegisterForm r f) _

formProxy :: F.FormProxy RegisterForm
formProxy = F.FormProxy

proxies :: F.SProxies RegisterForm
proxies = F.mkSProxies formProxy

validators :: forall m. Monad m => RegisterForm Record (F.Validation RegisterForm m)
validators = RegisterForm
  { username: V.required >>> V.usernameFormat
  , email: V.required >>> V.minLength 3 >>> V.emailFormat
  , password: V.required >>> V.minLength 8 >>> V.maxLength 20
  }

renderFormless :: forall m. MonadAff m => F.State RegisterForm m -> F.HTML' RegisterForm m
renderFormless fstate =
  HH.form_
    [ HH.fieldset_
      [ username
      , email
      , password
      ]
    , Field.submit "Sign up"
    ]
  where
  username = 
    Field.input proxies.username fstate.form 
      [ HP.placeholder "Username", HP.type_ HP.InputText ]

  email = 
    Field.input proxies.email fstate.form 
      [ HP.placeholder "Email", HP.type_ HP.InputEmail ] 

  password = 
    Field.input proxies.password fstate.form 
      [ HP.placeholder "Password" , HP.type_ HP.InputPassword ]