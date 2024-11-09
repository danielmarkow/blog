%{
title: "Phoenix auth in my own words",
author: "Daniel Markow",
description: "Build in Phoenix authentication explained"
}

---

## Introduction

I have recently fallen in love with Elixir and the Phoenix ecosystem for building web applications.
One of its strengths in my view is its readability. If one does not understand how something works, the source code
is there for you to read and understand. No magic. [Phoenix auth](https://hexdocs.pm/phoenix/mix_phx_gen_auth.html) is an inbuild DB sessions based authentication solution.
Simply running the command

```bash
mix phx.gen.auth Accounts User users
```

sets everything up for you in your app for you to either use as is or to modify for your individual demands.
If you want to modify it however you should understand it first.
In the following I will go through all of the flows that phoenix auth brings and explain them in my own words because this helped me understand what is going on and it might help you as well.
The text assumes you are working with live views.

## Registration flow in my own words

The user enters registration data in live view route /users/register. Upon hitting the "Create and Account" button the "save" handler in user_registration_live.ex is triggered.
The user information is saved to the database. Then the form action trigger is set to true which posts the form data to the url /users/log_in?_action=registered which then proceeds to create
user session such that the user is immediately logged in after registering when the account details are found in the database.
This route is "classical" controller based instead of a live view since the session cookie needs to be set in the header of the http request which is not possible in a live view since they are based on websockets.

## Login flow in my own words

The user enters login credentials in /user/log_in live view defined in user_login_live.ex.
This live view does not have a handler. Which means the form content is posted to the endpoint defined in the action parameter /users/log_in.
Which is also defined as a post controller based endpoint in the router which calls the user session controller which then proceeds to create a user session.

## Forgot password flow in my own words

The reset password flow enables you to create new password in case you have forgotten yours.
The user enters his email address, upon confirmation the "send_email" handler is called in user_forgot_password_live.ex.
There the DB is checked if the user exists if so the reset instructions are delivered via mail in Accounts.deliver_user_reset_password_instructions/2 - where
an encoded email token is generated as well as a user token. The user token is stored in the DB. Then the user notifier is triggered to send the user an email that
contains a link with the generated email-token as a parameter. For this to work an email service has to be configured with Swoosh.
If you are in a development environment and have no service configure visit /dev/mailbox to view the generated emails.

## Reset password flow in my own words

In the email generated in the forgot password flow the user is directed to users/reset_password/<email_token>.
The reset password form can be found in user_reset_password_live.ex. The mount function retrieves the user using the email token.
The "reset_password" event handler updates the password in the DB and then redirects to login.

## User email confirmation flow in my own words

Similar to the reset password flow a confirmation email is send upon registering which contains a links with a specially generated email token.
Opening that link the user is directed to /user/confirm/<email_token>. On mount the token is put into the socket. The "confirm_account" handler then triggers Accounts.confirm_user/1 that checks if the token exists in the DB and if so the account is set to verifyed.
