fs                = require('fs')
supertest         = require('supertest')
expect            = require('chai').expect
cheerio           = require('cheerio')
Search_Controller = require('../../src/controllers/Search-Controller')
Express_Service   = require('../../src/services/Express-Service')


describe "| controllers | Search-Controller.test |", ->

  @.timeout(3500)

  it "constructor", ->
      expect(Search_Controller).to.be.an('Function')

      req    = {}
      res    = {}

      using new Search_Controller(req, res), ->
        assert_Is_Null @.searchData
        @.req                    .assert_Is req
        @.res                    .assert_Is res
        @.jade_Service           .assert_Instance_Of require('../../src/services/Jade-Service')
        @.graph_Service          .assert_Instance_Of require('../../src/services/Graph-Service')
        @.defaultUser            .assert_Is 'TMContent'
        @.defaultRepo            .assert_Is 'TM_Test_GraphData'
        @.defaultFolder          .assert_Is '/SearchData/'
        @.defaultDataFile        .assert_Is 'Data_Validation'

        @.jade_Main              .assert_Is 'user/main.jade'
        @.jade_Search            .assert_Is 'user/search.jade'
        @.jade_Error_Page        .assert_Is 'guest/404.jade'
        @.jade_Search_two_columns.assert_Is 'user/search-two-columns.jade'

        assert_Is_Null @.searchData

  it 'render_Page', (done)->
    res =
      send : (html)->
        $ = cheerio.load html
        $('#results' ).html().assert_Is_String()
        $('#articles').html().assert_Is_String()
        done()
    using new Search_Controller(null, res),->
      @.render_Page @.jade_Search

  it 'get_Navigation', (done)->
    using new Search_Controller(),->
      @.graph_Service.resolve_To_Ids = (query_Id,callback)->
        callback { query_Id : { id: 'id-123', title: 'title-123'}}
      @.get_Navigation 'query-id-123', (data)->
        data.assert_Is [ { href: '/jade/show/query_Id', title: 'title-123', id: 'id-123' } ]
        done()


  it 'showSearchFromGraph', (done)->
    req    = { params: queryId : 'query-id'}
    res    =
              send: (html)->
                  html.assert_Is_String()
                  done()
    using new Search_Controller(req, res),->
      @.showSearchFromGraph()


  it 'show_Root_Query',(done)->

    test_Query_Id = 'query-'.add_5_Letters()
    test_Title    = 'query-title'.add_5_Letters()
    req    = { params: queryId : 'query-id'}
    res    =
              send: (html)->
                html.assert_Contains ('An error occurred')
                done()

    using new Search_Controller(req,res),->

      @.graph_Service =
        library_Query: (callback)->
          callback  { queryId  : test_Query_Id}
        resolve_To_Ids: (query_Id,callback)->
          query_Id.assert_Is test_Query_Id
          callback { query_Id : { id: test_Query_Id, title: test_Title }}
        graphDataFromGraphDB: (query_Id, filters, callback)->
          query_Id.assert_Is test_Query_Id
          callback {title:test_Title }

      @show_Root_Query()

  it 'showMainAppView', (done)->
    req    = { params: queryId : 'Logging', session: {}}
    res    =
        send: (html)->
          html.assert_Contains 'main-app-view'
          done()
    express_Service =
      session_Service :
        user_Data: (session, callback) ->
          callback {}

    using new Search_Controller(req, res),->
      @.express_Service = express_Service
      @.showMainAppView()


  describe 'showSearchFromGraph |', ->

    graph_Service = (on_GraphDataFromGraphDB)->
        resolve_To_Ids: (query_Id,callback)->
          callback { query_Id : { id: 'id-123', title: 'title-123'}}
        graphDataFromGraphDB: (query_Id, filters, callback)->
          searchData = on_GraphDataFromGraphDB(query_Id, filters)
          callback(searchData)

    it 'no query-name and filter (searchData is null)', (done)->
      req    = { params: {}}
      res    =
        send: (html)->
          $    = cheerio.load html
          $('#results').html().assert_Is_String()
          $('#articles').html().assert_Is_String()
          done()


      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service ()->
          return null

        @.showSearchFromGraph()

    it 'with query-name and filter (searchData is null)', (done)->
      req    = { params: {queryId : 'query-name' , filters:'filters-abc'}}
      res    =
        send: (html)->
          $    = cheerio.load html
          $('#results' ).text().assert_Is ''
          $('#articles').text().assert_Is ''
          done()


      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service ()->
          return null

        @.showSearchFromGraph()

    it 'with query-name no filter (valid searchData)', (done)->
      req    = { params: {queryId : 'query-name' , filters:null}}
      res    =
        send: (html)->
          $    = cheerio.load html
          $('#resultsTitle').text().assert_Is 'Showing 1 articles' + 'Showing 1 articles'
          $('#results'     ).html().contains('Showing 1 articles')
          $('#articles #list-view-article').html().assert_Is_String()
          $('#list-view-article #result-id-1 h4').html().assert_Is 'result-title-1'
          done()

      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service (query_Id, filters)->
          query_Id.assert_Is 'id-123'
          return { results: [ {id:'result-id-1', title:'result-title-1'}]}

        @.showSearchFromGraph()

    it 'with query-name and filter (valid searchData)', (done)->
      req    = { params: {queryId : 'query-name' , filters:'abc'}}
      res    =
        send: (html)->
          $    = cheerio.load html
          $('#resultsTitle').text().assert_Is 'Showing 1 articles' + 'Showing 1 articles'
          $('#results'     ).html().contains('Showing 1 articles')
          $('#articles #list-view-article').html().assert_Is_String()
          $('#list-view-article #result-id-1 h4').html().assert_Is 'result-title-1'
          $('#activeFilter').html().assert_Is 'title-123<span class="close"><a href="/jade/show/query_Id/abc">x</a></span>'
          done()

      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service (query_Id, filters)->
          query_Id.assert_Is 'id-123'
          return { results: [ {id:'result-id-1', title:'result-title-1'}]}

        @.showSearchFromGraph()


  describe 'search |', ->

    graph_Service = (on_Query_From_Text_Search,on_GraphDataFromGraphDB)->
      query_From_Text_Search: (text, callback)->
        callback on_Query_From_Text_Search(text)
      resolve_To_Ids: (query_Id,callback)->
        callback { query_Id : { id: 'id-123', title: 'title-123'}}
      search_Log_Empty_Search: (user, value, callback)->
          callback {}
      graphDataFromGraphDB: (query_Id, filters, callback)->
        callback on_GraphDataFromGraphDB(query_Id, filters)

    it 'no search text and null searchData', (done)->
      req    = { params: {}, session:{}}
      res    =
        send: (html)->
          cheerio.load html.assert_Contains 'results'
          done()

      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service (()-> null) , (()-> null )
        @.search()

    it 'no search text but {} as searchData', (done)->
      req    = { params: {}, session:{}}
      res    =
        send: (html)->
          html.assert_Contains 'results'
          done()

      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service (()-> '') , (()-> {} )
        @.search()

    it 'search text but {} as searchData', (done)->
      req    = { session:{}, query: text: 'text-search' }
      res    =
        send: (html)->
          html.assert_Contains 'results'
          $ = cheerio.load html
          $('#search-input').attr().assert_Is { id: 'search-input' }
          $('#results p').text().assert_Is 'No ResultsPlease try again' + 'No ResultsPlease try again'
          done()

      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service (()-> '') , (()-> {} )
        @.search()

    it 'search text, no filter, valid searchData', (done)->
      req    = { session:{}, query: text: 'text-search' }
      res    =
        send: (html)->
          html.assert_Contains 'results'
          $ = cheerio.load html
          $('#articles #list-view-article #result-id').attr().assert_Is { href: '/jade/article/result-id/title-id', id: 'result-id' }
          $('#list-view-article h4').html().assert_Is 'title-id'
          $('#activeFilter').text().assert_Is ''
          done()

      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service (()-> '') , (()-> { id:'search-id', results: [{id:'result-id', title:'title-id'}]} )
        @.search()

    it 'search text, filter, valid searchData', (done)->
      req    = { session:{}, query: text: 'text-search' , filters: '/filter-text'}
      res    =
        send: (html)->
          html.assert_Contains 'results'
          $ = cheerio.load html
          $('#articles #list-view-article #result-id').attr().assert_Is { href: '/jade/article/result-id/title-id', id: 'result-id' }
          $('#list-view-article h4').html().assert_Is 'title-id'
          $('#activeFilter').text().assert_Is 'title-123x' + 'title-123x'
          done()

      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service (()-> '') , (()-> { id:'search-id', results: [{id:'result-id', title:'title-id'}]} )
        @.search()

    it 'search using url', (done)->
      req    = { session:{}, query: {}, params: text: 'text-search' }
      res    =
        send: (html)->
          html.assert_Contains 'results'
          $ = cheerio.load html
          $('#articles #list-view-article #result-id').attr().assert_Is { href: '/jade/article/result-id/title-id', id: 'result-id' }
          done()

      using new Search_Controller(req, res),->
        @.graph_Service = graph_Service (()-> '') , (()-> { id:'search-id', results: [{id:'result-id', title:'title-id'}]} )
        @.search_Via_Url()

  it 'routes', ->
    using new Search_Controller(), ->
      @.routes().stack.size().assert_Is 9
      paths = for item in @.routes().stack
        if item.route
          item.route.path
      paths.assert_Is [ '/',
                        '/show',
                        '/show/:queryId',
                        '/show/:queryId/:filters',
                        '/user/main.html',
                        '/search',
                        '/search/:text',
                        '/json/search/recentsearch',
                        '/json/search/gateways' ]

  it 'Gateways',(done)->

    test_Query_Id = 'query-da0f0babaad8'
    test_Title    = 'query-title'.add_5_Letters()
    req    = { params: queryId : 'query-id'}
    res    =
      send: (html)->
        html.assert_Contains ('An error occurred')
        done()

    using new Search_Controller(req,res),->
      guides = __dirname.path_Combine('../resources/guides.json').load_Json()

      @.graph_Service =
        library_Query: (callback)->
          callback  { queryId  : test_Query_Id}
        resolve_To_Ids: (query_Id,callback)->
          query_Id.assert_Is test_Query_Id
          callback { query_Id : { id: test_Query_Id, title: test_Title }}
        graphDataFromGraphDB: (query_Id, filters, callback)->
          query_Id.assert_Is test_Query_Id
          callback guides

      @show_Gateways (guides)=>
        guides.title.assert_Is('Guides')
        guides.size.assert_Is(34)
        guides.containers.size()      .assert_Is(5)
        guides.containers[0].size     .assert_Is(5)
        guides.containers[0].articles .size().assert_Is(5)
        guides.containers[0].title    .assert_Is('Introduction')
        guides.containers[1].size     .assert_Is(1)
        guides.containers[1].articles .size().assert_Is(1)
        guides.containers[1].title    .assert_Is('Standards')
        guides.containers[2].size     .assert_Is(16)
        guides.containers[2].articles .size().assert_Is(16)
        guides.containers[2].title    .assert_Is('Programming Best Practices')
        guides.containers[3].size     .assert_Is(4)
        guides.containers[3].articles .size().assert_Is(4)
        guides.containers[3].title    .assert_Is('Platform-specific Guidance')
        guides.containers[4].size     .assert_Is(8)
        guides.containers[4].articles .size().assert_Is(8)
        guides.containers[4].title    .assert_Is('Vulnerabilities')
        done()

  describe 'using Express_Service | ',->

    tmpSessionFile = './_tmp_Session'

    after ->
      tmpSessionFile.assert_File_Deleted()

    it 'Create Express_Service and register Search_Controller routes', (done)->
      using new Express_Service(),->
        @.add_Session()
        @.app._router.stack.assert_Size_Is 3
        @.app.use new Search_Controller().routes()
        @.app._router.stack.assert_Size_Is 4



        supertest(@.app)
          .get('/user/main.html')
          .end (err,res)->
            res.text.assert_Contains('<li><a id="nav-about" href="/jade/guest/about.html">About</a></li>')
            done()

    it '/user/main.html', (done)->
      using new Express_Service(),->
        @.add_Session(tmpSessionFile)
        @.set_Views_Path()

        @.app.use '*', (req,res,next)->
          req.session.username = 'qa-test'
          next()

        #Search_Controller.register_Routes @.app, @
        @.app.use new Search_Controller().routes(@)

        supertest(@.app).get("/user/main.html")
                        .end (err,res)=>

                          assert_Is_Null err
                          res.text.contains 'Top Articles'
                          done()