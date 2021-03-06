request            = null
Article_Controller = null
Help_Controller    = null
Login_Controller   = null
Search_Controller  = null
Jade_Service       = null
Router             = null

class Flare_Controller

  dependencies: ->
    request            = require 'request'
    Article_Controller = require './Article-Controller'
    Help_Controller    = require './Help-Controller'
    Login_Controller   = require './Login-Controller'
    Search_Controller  = require './Search-Controller'
    Jade_Service       = require '../services/Jade-Service'
    {Router}           = require 'express'

  constructor: ()->
    @.dependencies()
    @.graphDb_Port       = global.config?.tm_graph?.port
    @.graphDb_Server     = "http://localhost:#{@.graphDb_Port}"


  render_Page: (req,res, next, params)=>
    area = req.params.area
    page = req.params.page
    if area
      path = "../TM_Flare/#{req.params.area}/#{req.params.page}.jade"
    else
      path = "../TM_Flare/#{req.params.page}.jade"
    using new Jade_Service(), ->
      res.send @.render_Jade_File path, params

  show_Article: (req,res)=>
    using new Article_Controller(req,res), ->
      @.jade_Article = '../TM_Flare/article-new-window-view.jade'
      @.article()

  navigate: (req,res)=>
    using new Search_Controller(req,res),->
      @.urlPrefix               = 'flare/navigate'
      @.jade_Main               = '../TM_Flare/navigate.jade' # 'user/main.jade'
      @.jade_Search             = '../TM_Flare/navigate.jade' # 'user/search.jade'
      @.jade_Error_Page         = '../TM_Flare/error-page.jade' # 'guest/404.jade'
      @.jade_Search_two_columns = '../TM_Flare/navigate.jade' # 'user/search-two-columns.jade'
      @.show_Root_Query()
      #@.render_Page req,res

  show_Help: (req,res)=>
    using new Help_Controller(req,res),->
      @.jade_Help_Index  = '../TM_Flare/misc/help-index.jade'
      @.jade_Help_Page   = '../TM_Flare/misc/help-page.jade'
      #@.jade_No_Image    = '../TM_Flare/guest/404.jade'
      if req.params.page
        @.show_Help_Page()
      else
        @.show_Index_Page()


  show_Navigate: (req,res)=>
    using new Search_Controller(req,res),->
      @.urlPrefix               = 'flare/navigate'
      @.jade_Search             = '../TM_Flare/navigate.jade' # 'user/search.jade'
      @.jade_Error_Page         = '../TM_Flare/error-page.jade' # 'guest/404.jade'
      @.showSearchFromGraph()

  user_Search: (req,res)=>
    using new Search_Controller(req,res),->
      @.jade_Search_two_columns = '../TM_Flare/navigate.jade' # 'user/search-two-columns.jade'
      @.search()

  user_Login: (req, res)=>
    using new Login_Controller(req,res), ->
      @.jade_LoginPage             = '../TM_Flare/get-started.jade'
      @.jade_LoginPage_Unavailable = '../TM_Flare/get-started.jade' #'../TM_Flare/login-cant-connect.jade'
      @.jade_GuestPage_403         = '../TM_Flare/get-started.jade' #'../TM_Flare/403.jade'
      @.page_MainPage_user         = '/flare/main-app-view'
      @.page_MainPage_no_user      = '/flare/index'
      @.loginUser()

  routes: ()=>
    using new Router(), ->
      flare_Controller = new Flare_Controller()
      @.get  '/article/:ref'              , flare_Controller.show_Article
      @.get  '/article/:ref/:title'       , flare_Controller.show_Article
      @.get  '/help-index'                , flare_Controller.show_Help
      @.get  '/help/:page*'               , flare_Controller.show_Help
      @.get  '/navigate'                  , flare_Controller.navigate
      @.get  '/navigate/:queryId'         , flare_Controller.show_Navigate
      @.get  '/navigate/:queryId/:filters', flare_Controller.show_Navigate
      @.post '/user/login'                , flare_Controller.user_Login
      @.get  '/user/search'               , flare_Controller.user_Search
      @.get  '/:page'                     , flare_Controller.render_Page
      @.get  '/:area/:page'               , flare_Controller.render_Page
      @.get  '/'                          , (req, res)-> res.redirect '/flare/index'
      @




module.exports = Flare_Controller