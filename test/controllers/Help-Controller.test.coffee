cheerio           = require 'cheerio'
express           = require 'express'
expect            = require('chai').expect
request           = require 'request'
marked            = require 'marked'
supertest         = require 'supertest'
Help_Controller   = require('../../src/controllers/Help-Controller')

describe '| controllers | Help-Controller.test |', ()->

  help_Controller = null
  on_Res_Send     = -> @
  on_Res_Status   = -> @
  req             = {}
  res             =
    status: (status)->
      status.assert_Is '200'
      @
  #send:
  #status: -> @
  library =
    Title    : 'library title'
    Articles : { 'article_id_2': { Title: 'article_title_2'},'1eda3d77-43e0-474b-be99-9ba118408dd3':{Title:'Introduction to TEAM Mentor'}}
    Folders  : []
    Views    : [ { Title: 'an view title', Articles: [ {Title:'an article title', Id: 'an article id'}]}]
    content  : 'library index page content'

  docs_TM_Service =
    getLibraryData: (callback)->
      callback [library]
    article_Data : (articleId) ->
      if (articleId=='1eda3d77-43e0-474b-be99-9ba118408dd3')
        return {html:'<p><strong>Welcome to TEAM Mentor.</strong> <br>\n</p><p>\nTEAM Mentor</p>'}

  check_Help_Page_Contents = (html, loggedIn, title, content, next)->

    $ = cheerio.load(html)
    # check top nav links
    if loggedIn
      $('#nav-user-logout').text().assert_Is 'Logout'
    else
      $('#nav-login'              ).text().assert_Is 'Login'
    # check right nav links
    $('#help-nav h4'     ).html().assert_Is 'an view title'
    $('#help-nav tr td a').attr().assert_Is { href: '/jade/help/an article id' }
    $('#help-nav tr td a').html().assert_Is 'an article title'
    # check content
    if (title or content)
      $('#help-title'  ).text().assert_Is title
      $('#help-content').text().assert_Is content
    else
      $('#help-title').html().assert_Is 'Introduction to TEAM Mentor'
      $('p strong   ').html().assert_Is 'Welcome to TEAM Mentor.'
    next()

  @.timeout 5000

  before (done)->
    using new Help_Controller(req,res), ->
      help_Controller = @
      @.docs_TM_Service = docs_TM_Service
      done()

  it 'constructor', (done)->
    using new Help_Controller(req,res),->

      @.pageParams      .assert_Is({})
      @.req             .assert_Is(req)
      @.res             .assert_Is(res)
      @.docs_TM_Service.assert_Instance_Of require('../../src/services/Docs-TM-Service')

      assert_Is_Null(@.content)
      assert_Is_Null(@.docs_Library)
      assert_Is_Null(@.title)

      @.docs_Server     .assert_Is 'https://docs.teammentor.net'
      @.gitHubImagePath .assert_Is 'https://raw.githubusercontent.com/TMContent/Lib_Docs/master/_Images/'
      @.jade_Help_Index .assert_Is 'misc/help-index.jade'
      @.jade_Help_Page  .assert_Is 'misc/help-page.jade'

      done()

  it 'content_Cache_Get, content_Cache_Set', (done)->
    content = 'content_'.add_5_Letters()
    page_Id = 'id'     .add_5_Letters()
    title   = 'title_' .add_5_Letters()

    using help_Controller,->
      @.req      = { params: page: page_Id }
      @.content_Cache_Set title, content
      @.content_Cache_Get().assert_Is { title: title, content: content}
      done()

  it 'content_Cache', ->
    using help_Controller,->
      for key in @.content_Cache().keys()
        delete @.content_Cache()[key]
      @.content_Cache().assert_Is {}

  it 'map_Docs_Library', (done)->
    using help_Controller,->
      @.docs_Library = null
      @.map_Docs_Library =>
        @.docs_Library.Title.assert_Is 'library title'
        done()

  it 'page_Id', (done)->
    page_Id = 'id'     .add_5_Letters()
    using help_Controller,->
      @.req      = { params: page: page_Id }
      @.page_Id().assert_Is page_Id
      done()

  it 'render_Jade_and_Send', (done)->
    view_Model =
      title:   'title_'.add_5_Letters()
      content: 'content_'.add_5_Letters()
    using help_Controller,->
      @.res.send = (html)->
        check_Help_Page_Contents html, false, view_Model.title, view_Model.content, done

      @.render_Jade_and_Send @.jade_Help_Page, view_Model


  it 'show_Content', (done)->
    page_Id = 'id'     .add_5_Letters()
    title   = 'title_' .add_5_Letters()
    content = 'content_'.add_5_Letters()
    using help_Controller,->
      @.req      = { params: page: page_Id }
      @.res.send = (html)=>
        check_Help_Page_Contents html, false, title, content, =>
        done()
      @.show_Content title, content

  it 'show_Help_Page (no content)' , (done)->
    using help_Controller,->
      @.req      = {}
      @.res.send = (html)-> check_Help_Page_Contents html, false, 'No content for the current page', '', done
      @show_Help_Page()

  it 'show_Help_Page (from content_Cache)' , (done)->
    page_Id = 'id'     .add_5_Letters()
    title   = 'title_' .add_5_Letters()
    content = 'content_'.add_5_Letters()
    using help_Controller,->
      @.req      = { params: page: page_Id }
      @.content_Cache()[page_Id] = { title: title, content: content }
      @.res.send = (html)-> check_Help_Page_Contents html, false, title,content, done
      @show_Help_Page()

  it 'show_Image (when image exists)', (done)->
    using help_Controller,->
      @.imagePath.assert_Folder_Exists()
      image_Path = @.imagePath.files('.jpg').assert_Not_Empty().first()
      image_Name = image_Path.file_Name()
      @.req = { params: name: image_Name}

      @.res.sendFile = (data)->
        data.assert_Is image_Path
        done()

      @.show_Image()

  it 'show_Image (when image not exists)', (done)->
    req = { params: name: 'AAAAAA-BBBBB'}
    res =
      status: (code)->
        code.assert_Is 404
        @
      send  : (data)->
        data.assert_Contains 'a HTTP 404 error'
        done()
    using new Help_Controller(req,res), ->
      @.show_Image()

  it 'show_Index_Page (anonymous users)', (done)->
    page_Id = 'id'     .add_5_Letters()
    using help_Controller,->
      @.req      = { params: page: page_Id }
      @.res.send = (html)-> check_Help_Page_Contents html, false, null, null, done
      @.show_Index_Page()

  it 'show_Index_Page (logged in users)', (done)->
    page_Id = 'id'     .add_5_Letters()
    using help_Controller,->
      @.req          = {}
      @.req.session  = username : 'aaaa'
      @.req.params   = page: page_Id
      @.res.send = (html)-> check_Help_Page_Contents html, true, null, null, done
      @.show_Index_Page()

  it 'user_Logged_In',(done)->
    using help_Controller,->
      @.req = {}
      @.user_Logged_In().assert_False()
      @.req = session: null
      @.user_Logged_In().assert_False()
      @.req = session: username: 'a'
      @.user_Logged_In().assert_True()
      done()

  it 'routes', ()->
    app               = new express()
    app.use new Help_Controller().routes()
    paths = []
    for item in app._router.stack
      if item.handle.stack
        for subitem in item.handle.stack
          if subitem.route
            paths.push subitem.route.path

    paths.assert_Is [ '/help/index.html',
                      '/help/article/:page*',
                      '/help/:page*',
                      '/Image/:name',
                      '/json/docs/library',
                      '/json/docs/:page' ]

  describe 'using mocked docs tm server |', ->

    app               = null
    server            = null
    url_Mocked_Server = null
    on_Content        = ->
    help_Controller   = null

    before (done)->
      random_Port       = 10000.random().add(10000)
      url_Mocked_Server = "http://localhost:#{random_Port}"
      app               = new express()
      app.get           '/content/:page', (req,res)-> on_Content(req,res)
      server            = app.listen(random_Port)
      using new Help_Controller(req,res), ->
        help_Controller = @
        @.docs_TM_Service = docs_TM_Service
        @.map_Docs_Library ->
          done()

    after ->
      server.close()

    check_Show_Content = (expected_Title, expected_html, errorMessage, next)->
      using help_Controller,->
        @.show_Content = (article_Title, body)->
          if errorMessage
            article_Title.assert_Is errorMessage
          else
            article_Title.assert_Is expected_Title
            body         .assert_Is expected_html
          next()
        @.fetch_Article_and_Show(expected_Title)

    it 'fetch_Article_and_Show (no title)', (done)->
      check_Show_Content null, null, 'No content for the current page', done

    it 'fetch_Article_and_Show (bad server)', (done)->
      using help_Controller, ->
        docs_TM_Service =
          article_Data : (articleId) ->
            return false
        @.docs_TM_Service =docs_TM_Service
        check_Show_Content 'aaaa','', 'Error fetching page from docs site', done

    it 'fetch_Article_and_Show (valid server, good response)', (done)->
      article_Title = 'an_title_'.add_5_Letters()
      page_Id       = 'an_id_'.add_5_Letters()
      help_Content  = '<h1>Test</h1>'

      on_Content        = (req,res)->
        req.params.page.assert_Is page_Id
        res.send(help_Content)

      using help_Controller, ->
        docs_TM_Service =
          article_Data : (articleId) ->
            return {html: help_Content}
        @.docs_TM_Service =docs_TM_Service
        @.req = { params: page: page_Id }
        check_Show_Content article_Title,help_Content, null, done

    it 'fetch_Article_and_Show (valid server, bad response)', (done)->

      on_Content        = (req,res)->
        res.send(null)

      using help_Controller, ->
        docs_TM_Service =
          article_Data : (articleId) ->
            return false
        @.docs_TM_Service =docs_TM_Service
        @.req = { params: page: 'abc' }
        check_Show_Content 'a','', 'Error fetching page from docs site', done

    it 'show_Help_Page (valid server, good response)', (done)->
      page_Id       = library.Articles.keys().first()
      article_Title = library.Articles[page_Id].Title
      help_Content  = '<h1>Test</h1>'

      on_Content        = (req,res)->
        req.params.page.assert_Is page_Id
        res.send(help_Content)

      using new Help_Controller(req,res), ->
        docs_TM_Service =
          getLibraryData: (callback)->
            callback [library]
          article_Data : (articleId) ->
            return {html:'<h1>Test</h1>'}
        @.docs_TM_Service = docs_TM_Service
        @.req = { params: page: page_Id }
        @.render_Jade_and_Send = (jade_Page, view_Model)=>
          jade_Page         .assert_Is @.jade_Help_Page
          view_Model.title  .assert_Is article_Title
          view_Model.content.assert_Is help_Content
          @.content_Cache()[page_Id].assert_Is view_Model
          done()

        @.show_Help_Page()

  describe 'using express |', ->

    app               = null
    server            = null
    url_Mocked_Server = null
    help_Controller   = null

    before ->
      random_Port       = 10000.random().add(10000)
      url_Mocked_Server = "http://localhost:#{random_Port}"
      app               = new express()
      app.use new Help_Controller().routes()
      server            = app.listen(random_Port)

    after ->
      server.close()

    it 'show_Image (image exists)', (done)->
      supertest(app)
        .get('/Image/editingoverview-img2.jpg')
        .end (err, res)->
          res.status.assert_Is 200
          res.type  .assert_Is 'image/jpeg'
          res.body.length.assert_Is_Bigger_Than 1000
          done()

    it 'show_Image (image not exists)', (done)->
      supertest(app)
        .get('/Image/aaaa-bbb')
        .end (err, res)->
          res.status.assert_Is 404
          res.text.assert_Contains 'a HTTP 404 error'
          done()