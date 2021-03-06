express          = require 'express'
supertest        = require 'supertest'
Flare_Controller = require '../../src/controllers/Flare-Controller'

describe '| controllers | Flare-Controller |', ->

  it 'constructor',->

    using new Flare_Controller(),->
      @.assert_Is_Object()

  describe 'using Express |', ->

    app = null

    before ->
      app  = new express()
      app.use new Flare_Controller().routes()

    it 'check route ', (done)->
      supertest(app)
        .get('/flare')
        .end (err, response, html)->
          log response.text
          done()