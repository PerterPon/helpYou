#!/usr/bin/env coffee
try 
  require 'coffee-script'

  connect  = require 'connect'
  allinone = require './spts/lib/allInOne'

  port     = process.env.APP_PORT || 8000

  app      = connect()
  aio      = allinone()

  app.use connect.static "#{__dirname}/public"
  app.use '/s/', aio.middleWare
  app.listen port
catch e
  console.log e
