require 'fluentnode'

Article_Controller = require '../../src/controllers/Article-Controller'
Express_Service    = require '../../src/services/Express-Service'
Session_Service    = require '../../src/services/Session-Service'
cheerio            = require 'cheerio'
supertest          = require 'supertest'

describe '| controllers | Article-Controller.test', ->

  global.config = null

  it 'constructor', (done)->
    using new Article_Controller(), ->
      @.jade_Article.assert_Is    'user/article.jade'
      @.jade_No_Article.assert_Is 'user/no-article.jade'
      done()

  it 'article (bad id)', (done)->
    article_Id = 123
    req =
      params : ref: article_Id
      session: recent_Articles: []
      get    : (name)->
        name.assert_Is 'host'
        return 'localhost'

    res =
      send : (data)->
        $ = cheerio.load(data)
        $('#article #oops').html().assert_Is 'Oops'
        $('#article p'    ).html().assert_Is 'That article doesn&apos;t exist.'
        done()

    graphService =
      article:  (id, callback)->
        id.assert_Is article_Id
        callback { }

    using new Article_Controller(req,res),->
      @.graphService = graphService
      @.article()

  it 'article (good id, verify syntax highlighting)', (done)->

    article_Id    = 'article-12345'
    article_Title = 'this is an title'
    article_Text  = 'html is here '
    article_Html  = 'html is here <pre> var a =12 </pre>'

    req =
      params: ref: article_Id
      session: recent_Articles: []
      get: (name)->
        name.assert_Is 'host'
        'localhost'

    res =
      send : (data)->
        $ = cheerio.load(data)

        $('#article #title').html().assert_Is article_Title
        html = $('#article #html' ).html().assert_Contains article_Text
                                          .assert_Contains('<pre> <span class="keyword">')
        $.html().assert_Contains('<link href="/css/syntax-highlighting-github-style.css" rel="stylesheet">')
        done()

    graphService =
      article:  (id, callback)->
        if id is article_Id
          callback { article_Id: id }
      node_Data: (id, callback)->
        if id is article_Id
          callback { title: article_Title }
      article_Html: (id, callback)->
        if id is article_Id
          callback { html: article_Html }

    using new Article_Controller(req,res), ->
      @.graphService = graphService
      @.article()

  it 'articles', (done)->

    article_Id      = 'article-12345'
    article_Title   = 'this is an title'
    article_Summary = 'html summary is here'

    req =

    res =
      send : (data)->
        $ = cheerio.load(data)
        $('#articles').html()
        $('#articles').html().assert_Contains 'list-view-article'
        $('#articles #list-view-article a').attr().assert_Is { href: '/jade/article/12345/this-is-an-title', id: 'article-12345' }
        $('#articles #list-view-article a h4').html().assert_Is 'this is an title'
        $('#articles #list-view-article p').html().assert_Is 'html summary is here...'
        done()

    graphService =
      articles: (callback)->
        callback { article_Id: {
                    guid    : "00000000-0000-0000-0000-000000026eca",
                    title   : article_Title
                    summary : article_Summary
                    is      : "Article",
                    id      : article_Id
                  }}

    using new Article_Controller(req,res), ->
      @.graphService = graphService
      @.articles()


  it 'check_Guid (bad guid v1)', (done)->

    new Article_Controller {params: guid : 'article-20bc957875f7'}, null, done
            .check_Guid()

  it 'check_Guid (bad guid v2)', (done)->
    new Article_Controller {params: guid : '/XML-External-Entity-(XXE)-Injection'}, null, done
      .check_Guid()

  it 'check_Guid (valid guid)', (done)->
    req =
      params: guid : '5b653aa9-7669-4dcb-88d2-8b0f601da772'
    res =
      redirect: (target)=>
        target.assert_Is "/article/#{req.params.guid}"
        done()

    using new Article_Controller(req,res), ->
      @.check_Guid()

  it 'recentArticles, recentArticles_add', (done)->
    article_Id    = 'id-aaaaaaaa'
    article_Title = 'title-bbbbb'

    req =
      params: id : article_Id
      session: recent_Articles: []
      get: (name)->
        name.assert_Is 'host'
        'localhost'
      
    res = {}

    graphService =
      article     : (id, callback) -> callback {article_Id: article_Id }
      node_Data   : (id, callback) -> callback {title     : article_Title }
      article_Html: (id, callback) -> callback {html      : null }

    using new Article_Controller(req,res), ->
      @recentArticles().assert_Is []                        # check default value and using recentArticles_Add directly
      @recentArticles_Add 'id_abc','title_123'
      @recentArticles().assert_Is [{'href' : '/article/id_abc', 'title' : 'title_123'}]

      @.graphService = graphService                         # check via (simulated) call to article()
      res.send =  ()=>
        @recentArticles().assert_Size_Is 2
        @recentArticles().first().assert_Is {'href' : "/article/#{article_Id}", 'title' : article_Title}

        @recentArticles_Add 'id_1111','title_1111'          # add another one directly
        @recentArticles().assert_Size_Is 3
        @recentArticles().second().assert_Is {'href' : "/article/#{article_Id}", 'title' : article_Title}

        @recentArticles_Add 'id_2222','title_2222'          # and another one
        @recentArticles().assert_Size_Is 3
        @recentArticles().third().assert_Is {'href' : "/article/#{article_Id}", 'title' : article_Title}

        @recentArticles_Add 'id_3333','title_3333'          # last one so that we have a full set
        @recentArticles().assert_Size_Is 3
        @recentArticles().first() .assert_Is {'href' : '/article/id_3333', 'title' : 'title_3333'}
        @recentArticles().second().assert_Is {'href' : '/article/id_2222', 'title' : 'title_2222'}
        @recentArticles().third() .assert_Is {'href' : '/article/id_1111', 'title' : 'title_1111'}

        done()

      @.article()

  it 'my-articles', ()->
    req =
      query  : {}
      session: recent_Articles: [ { title:'title-1', id:'id-1'}, { title:'title-1', id:'id-1'},
                                  { title:'title-2', id:'id-2'}
                                  { title:'title-1', id:'id-3'} ]
    res =
      json: (data)->
        data.assert_Is [{ href: '/article/id-1', title: 'title-1', weight: 2 },
                        { href: '/article/id-3', title: 'title-1', weight: 1 }
                        { href: '/article/id-2', title: 'title-2', weight: 1 }]


    new Article_Controller(req,res).my_Articles()

    req.params  = size : 'aaaa'

    new Article_Controller(req,res).my_Articles()

    req.params  = size : '1'
    res =
      json: (data)->
        data.assert_Is [{ href: '/article/id-1', title: 'title-1', weight: 2 }]

    new Article_Controller(req,res).my_Articles()

  it 'routes', ->
    using new Article_Controller(), ->
      @.routes().stack.size().assert_Is 10
      paths = for item in @.routes().stack
        if item.route
          item.route.path
      paths.assert_Is [ '/a/:ref',
                        '/article/:ref/:guid',
                        '/article/:ref/:title',
                        '/article/:ref',
                        '/articles',
                        '/teamMentor/open/:guid',
                        '/json/article/:ref',
                        '/json/recentarticles',
                        '/json/toparticles',
                        '/json/my-articles/:size']