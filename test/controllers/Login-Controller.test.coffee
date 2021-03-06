express                 = require 'express'
bodyParser              = require 'body-parser'
Login_Controller        = require '../../src/controllers/Login-Controller'
config                  = require '../../src/config'

describe '| controllers | Login-Controller.test |', ->

  #consts
  loginPage                 = 'guest/login-Fail.jade'
  loginPage_Unavailable     = 'guest/login-cant-connect.jade'
  indexPage                 = '/jade/show'
  mainPage_no_user          = '/jade/guest/default.html'
  blank_credentials_message = 'Invalid Username or Password'
  random_Port               = 10000.random().add(10000)

  #mocked server
  server                   = null
  users                    =  { tm: 'tm' , user: 'a'  }
  on_Login_Response        = null

  add_TM_WebServices_Routes = (app)=>
    app.post '/Aspx_Pages/TM_WebServices.asmx/Login_Response', (req,res)=>
      if on_Login_Response
        return on_Login_Response(req, res)
      username = req.body.username
      password = req.body.password
      if users[username]
        if users[username] is password
          res.send { d: { Login_Status: 0}  }
        else
          res.send { d: { Login_Status: 1, Simple_Error_Message: 'Wrong Password'  } }
      else
        res.send { d: { Login_Status: 1, Validation_Results: [{Message: 'Bad user and pwd'} ] } }

    app.post '/Aspx_Pages/TM_WebServices.asmx/Current_User', (req,res)=>
      res.json { d: { Email: 'aaaa@bbb.com' } }

  before (done)->
    app             = new express().use(bodyParser.json())
    add_TM_WebServices_Routes(app)
    server          = app.listen(random_Port)

    "http://localhost:#{random_Port}/Aspx_Pages/TM_WebServices.asmx".GET (html)->
      html.assert_Is 'Cannot GET /Aspx_Pages/TM_WebServices.asmx\n'
      done()

  beforeEach ()->
    config.options.tm_design.tm_35_Server = "http://localhost:#{random_Port}"

  afterEach ->
    config.restore()

  after ->
    server.close()


  invoke_Method = (method, body, expected_Target, callback)->
    req =
      session: {}
      url    : '/passwordReset/temp/00000000-0000-0000-0000-000000000000'
      body   : body

    res =
      redirect: (target)->
        target.assert_Is(expected_Target)
        callback()

    render_Page = (target) ->
      target.assert_Is(expected_Target)
      callback()

    using new Login_Controller(req, res), ->
      @.render_Page = render_Page
      @[method]()

  invoke_LoginUser = (username, password, expected_Target, callback)->
    invoke_Method "loginUser",
                  { username : username , password : password } ,
                  expected_Target,
                  callback

  it 'constructor', ->
    using new Login_Controller,->
      @.req             .assert_Is {}
      @.res             .assert_Is {}

    using new Login_Controller('req', 'res'),->
      @.req             .assert_Is 'req'
      @.res             .assert_Is 'res'

  it "loginUser (server not ok)", (done)->
    req = body: {username:'aaaa', password:'bbb'}
    res = null
    render_Page = (jade_Page, params)->
        jade_Page.assert_Is loginPage_Unavailable
        params.assert_Is { viewModel: {"username":"","password":"", errorMessage: "TEAM Mentor is unavailable, please contact us at " } }
        done()

    using new Login_Controller(req, res), ->
      @.render_Page = render_Page
      config.options.tm_design.tm_35_Server = 'http://aaaaaabbb.teammentor.net'
      @.loginUser()

  it "loginUser (server ok - null response)", (done)->
    on_Login_Response = (req,res)->
      res.send null

    invoke_LoginUser 'aaa','bbb', loginPage_Unavailable, ->
      on_Login_Response = null
      done()

  it "loginUser (bad username, password)", (done)->
    invoke_LoginUser '','', loginPage, ->                # empty username and pwd
      invoke_LoginUser 'aaa','', loginPage, ->           # empty pwd
        invoke_LoginUser '','bbb', loginPage, ->         # empty username
          invoke_LoginUser 'aaa','bbb', loginPage, ->    # bad username and pwd
            invoke_LoginUser '','bb', loginPage, ->      # blank username
              invoke_LoginUser 'aa','', loginPage, ->    # blank password
                invoke_LoginUser '','', loginPage,done   # blank credentials

  it "loginUser (local-good username, password)", (done)->
    invoke_LoginUser 'tm','tm', indexPage, ->
      invoke_LoginUser 'user','a', indexPage, done

  it "loginUser (undefined Login_Status using existential operator)", (done)->
    invoke_LoginUser undefined ,undefined , loginPage, done

  it 'logoutUser', (done)->
    invoke_Method "logoutUser", {} ,mainPage_no_user,done

  it 'invalid Username or Password (missing username)',(done)->
    newUsername  =''
    newPassword  = 'aaa'.add_5_Letters()

    render_Page = (jadePage,model)->                                     # render contains the file to render and the view model object
      model.viewModel.errorMessage.assert_Is(blank_credentials_message)  # verifying the message from the backend.
      jadePage.assert_Is('guest/login-Fail.jade')
      done()
    req = body:{username:newUsername,password:newPassword},session:'';
    res = null

    using new Login_Controller(req, res) ,->
      @.render_Page = render_Page
      @.loginUser()


  it 'invalid Username or Password (missing password)',(done)->
    newUsername         = 'aaa'.add_5_Letters()
    newPassword         =''

    render_Page = (jadePage,model)->                                      # render contains the file to render and the view model object
      model.viewModel.errorMessage.assert_Is(blank_credentials_message)   # verifying the message from the backend.
      jadePage.assert_Is('guest/login-Fail.jade')
      done()
    req = body:{username:newUsername,password:newPassword},session:'';
    res = null

    using new Login_Controller(req, res) ,->
      @.render_Page = render_Page
      @.loginUser()

  it 'invalid Username or Password (missing both username and password)',(done)->
    newUsername         =''
    newPassword         =''

    #render contains the file to render and the view model object
    render_Page = (jadePage,model)->
      #Verifying the message from the backend.
      model.viewModel.errorMessage.assert_Is(blank_credentials_message)
      jadePage.assert_Is('guest/login-Fail.jade')
      done()
    req = body:{username:newUsername,password:newPassword},session:'';
    res = null

    using new Login_Controller(req, res) ,->
      @.render_Page = render_Page
      @.loginUser()

  it 'login form persist HTML form fields on error (Wrong Password)',(done)->
    newUsername         ='tm'
    newPassword         ='aaa'.add_5_Letters()

    #render contains the file to render and the view model object
    render_Page = (html,model)->
      model.viewModel.username.assert_Is(newUsername)
      model.viewModel.password.assert_Is('')
      model.viewModel.errorMessage.assert_Is('Wrong Password')
      done()
    req = body:{username:newUsername,password:newPassword}, session:''
    res = null

    using new Login_Controller(req, res), ->
      @.render_Page = render_Page
      @.loginUser()

  it 'login form persist HTML form fields on error (Wrong username)',(done)->
    newUsername         = 'aaa'.add_5_Letters()
    newPassword         = 'bbb'.add_5_Letters()

    render_Page = (jade_Page,params)->
      jade_Page.assert_Is loginPage
      params.viewModel.errorMessage.assert_Is 'Bad user and pwd'
      done()

    req = body: {username:newUsername, password:newPassword}, session:''
    res = null

    using new Login_Controller(req, res), ->
      @.render_Page = render_Page
      @.loginUser()

  it 'Redirect upon login when URL is correct',(done)->
    newUsername         = 'tm'
    newPassword         = 'tm'

    redirect = (jade_Page)->
      jade_Page.assert_Is_Not_Null()
      jade_Page.assert_Is('/foo/bar')
      done()

    req = body: {username:newUsername, password:newPassword}, session:{redirectUrl:'/foo/bar'}
    res = redirect: redirect

    using new Login_Controller(req, res), ->
      @.loginUser()

  it 'Redirect upon login when URL is not a local URL',(done)->
    newUsername         = 'tm'
    newPassword         = 'tm'

    redirect = (jade_Page)->
      jade_Page.assert_Is_Not_Null()
      jade_Page.assert_Is(indexPage)
      done()

    req = body: {username:newUsername, password:newPassword}, session:{redirectUrl:'https://www.google.com'}
    res = redirect: redirect

    using new Login_Controller(req, res), ->
      @.loginUser()
