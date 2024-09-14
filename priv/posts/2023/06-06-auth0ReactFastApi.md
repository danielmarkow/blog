%{
title: "Using Auth0 for Authentication with FastAPI and React",
author: "Daniel Markow",
description: "Auth0 to safely auth API class from a React frontend"
}

---

FastAPI is a wonderful framework for writing APIs. It is very fast (as the name says) and very intuitive to learn if you have prior experience with Python. In the past I had used the serverless functions provided by Vercel for my backend but kind of had been fed up with the slow cold starts. The workaround - to only use V8 engine JavaScript - seemed crazy to me. Why would I make this trade-off? To save cents on permanently running a container that can be sized to load? Additionally I had a bad gut feeling relying on the admittedly awesome Vercel services for everything I do. Thus I decided to use FastAPI for the backend of a new project of mine with a React frontend.

The question then was how to facilitate authentication. In the past I had used either NextAuth or Clerk. The first wasn’t valid because I wasn’t using NextJS but basic React with Vite and I am not the biggest fan of database sessions. Clerk doesn’t have a Python API which you don’t really need for basic authentication with JWTs but might become relevant later if you need access to your users data. So I decided to give Auth0 a try.

The developer experience of Auth0 in my opinion isn’t as good as Clerks. Everything seems more complicated - although they do offer more features so maybe that complexity is justified.

Setting up the application in the Auth0 console is a little bit confusing because in Auth0 land a back- and a frontend are two separate applications. For the backend log in to [Auth0.com](http://Auth0.com), go to Applications → APIs and then click “+ Create API”. Important here is the “audience” which strangely is some imaginary url. You need to provide this audience parameter to your frontend applications as well. That is how they know that they belong together. Aside from that [this](https://developer.auth0.com/resources/code-samples/full-stack/hello-world/basic-access-control/spa/react-javascript/fastapi-python) tutorial is rather good in explaining how to set things.

There is an example for securing the FastAPI backend [here](https://github.com/auth0-developer-hub/api_fastapi_python_hello-world) but I found the heavily object oriented implementation of the validation functionality too complicated. I am not a fan of object oriented programming. I find that it obscures things rather than making it easier to understand the code. OOP enthusiasts probably will respond that the point is to hide complexity away but that doesn’t eliminate that one needs to understand what is happening especially in the absence of documentation. In corporate projects OOP is often used to enforce certain practices which to me feels dishonest. Just talk to your developers!

That is why I decided to implement my own:

```jsx
import jwt

from fastapi import HTTPException
from starlette.requests import Request as StarletteRequest
from config import settings

def validate(req: StarletteRequest):
   auth0_issuer_url: str = f"https://{settings.auth0_domain}/"
   auth0_audience: str = settings.auth0_audience
   algorithm: str = "RS256"
   jwks_uri: str = f"{auth0_issuer_url}.well-known/jwks.json"
   authorization_header = req.headers.get("Authorization")

   if authorization_header:
      try:
         authorization_scheme, bearer_token = authorization_header.split()
      except ValueError:
         raise HTTPException(401, "bad credentials")

      valid = authorization_scheme.lower() == "bearer" and bool(bearer_token.strip())
      if valid:
         try:
            jwks_client = jwt.PyJWKClient(jwks_uri)
            jwt_signing_key = jwks_client.get_signing_key_from_jwt(
               bearer_token
            ).key
            payload = jwt.decode(
               bearer_token,
               jwt_signing_key,
               algorithms=algorithm,
               audience=auth0_audience,
               issuer=auth0_issuer_url
            )
         except jwt.exceptions.PyJWKClientError:
            raise HTTPException(500, "unable to verify credentials")
         except jwt.exceptions.InvalidTokenError:
            raise HTTPException(401, "bad credentials")
         yield payload
   else:
      raise HTTPException(401, "bad credentials")
```

It first validates the format of the authentication header. Then it proceeds to validate the JWT itself using the applications auth0 credentials. I inject it with the FastAPI Depends method.

Another thing to watch out for is that Pydantic models in FastAPI may not be mutated. When I wrote this validation function I wanted to have the payload of the JWT available in my route function so I would not have to send userIDs and other sensitive information over the network. Unfortunately you just can’t append to or cast a PostInput model which comes in without the userId of the author. One option it seems is to forgo validation which of course is not a real option. This is a major downside of FastAPI/Pydantic in my mind. After the initial validation one should be able to mutate into a different object.

On the frontend things are less complicated and more akin to what Clerk is doing. One needs to install @auth0/auth0-react and then add a provider in the root of the application like so:

```tsx
import React from "react";
import ReactDOM from "react-dom/client";
import App from "./App.tsx";
import "./index.css";
import { Auth0Provider } from "@auth0/auth0-react";

ReactDOM.createRoot(document.getElementById("root") as HTMLElement).render(
  <React.StrictMode>
    <Auth0Provider
      domain={import.meta.env.VITE_AUTH0_DOMAIN}
      clientId={import.meta.env.VITE_AUTH0_CLIENT_ID}
      authorizationParams={{
        redirect_uri: window.location.origin,
        audience: import.meta.env.VITE_AUTH0_AUDIENCE,
      }}
    >
      <App />
    </Auth0Provider>
  </React.StrictMode>
);
```

You can then use the useAuth0 hook to login, logout and check if its one or the other.
