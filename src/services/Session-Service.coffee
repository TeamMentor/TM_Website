Nedb            = null
Express_Session = null
request         = null
async           = null
config          = null

class Session_Service

  DEFAULT_SEARCHES:  [{ id :'search-prevent-sql-injection'   , title: 'prevent sql injection'    , results:10},
                      { id :'search-xss'                     , title: 'xss'                      , results:10},
                      { id :'search-secure-connection-string', title: 'secure connection string' , results:10}]
  DEFAULT_ARTICLES:
                      [{id: '6eb42f9b93e6', title: 'Programming Best Practices'         },
                       {id: '20d72f7c1650', title: 'Platform-specific Guidance'         },
                       {id: '7a72e359eb7b', title: 'Vulnerabilities'                    }]
  
  dependencies: ()->
    Nedb            = require('nedb')
    Express_Session = require 'express-session'
    request         = require 'request'
    async           = require 'async'
    config          = require '../config'

  constructor: (options)->
    @.dependencies()
    @.options = options || {}
    @.filename = @.options.filename || './.tmCache/_sessionData' #"_session_Data"
    @.db = new Nedb(@.filename)
    Session_Service.prototype.__proto__ = Express_Session.Store.prototype;
    @.url_WebServices                   = @.options.webServices ||"#{global.config?.tm_design?.tm_35_Server}#{global.config?.tm_design?.webServices}"
    @.sessionTimeout_In_Minutes         = config.options.tm_design.session_Timeout_Minutes

  setup: (callback)=>
    @.session = Express_Session({ secret: '1234567890', key: 'tm-session'
                                , saveUninitialized: false , resave: true
                                , cookie: { path: '/' , httpOnly: true , maxAge: 1000 * 60 *  parseInt(@.sessionTimeout_In_Minutes)}
                                , store: @ })
    @.db.loadDatabase =>
      @.db.persistence.setAutocompactionInterval(30 * 1000) # set to 30s
      @.clear_Empty_Sessions ->
        logger?.info('[Session_Service] Configured')
        callback() if callback
      #based on code from https://github.com/louischatriot/connect-nedb-session/blob/master/index.js
      Session_Service.prototype.destroy = (sid, callback) =>
        @db.remove { sid: sid }, { multi: true }, (err, callback) ->
          return callback = err
    @

  logout_User: (token, callback)=>
    options =
      method    : 'post',
      body      : {},
      json      : true,
      headers   : {'Cookie':'Session='+token}
      url       : @.url_WebServices + '/Logout'
    request options, (error, response)=>
      if error
        logger?.info ('Could not connect with TM 3.5 server')
        callback null
      else
        callback response?.body?.d

  clear_Empty_Sessions: (callback)=>
    logger?.info "[Session_Service] clearing empty sessions"
    cleared = 0
    @.db.find {}, (err,sessionData)=>
      for session in sessionData
        expirationDate   = new Date (session.data.sessionExpirationDate)    #Expiry date from cookie
        token            = session.data.token                               #Token to invalidate TM 3.6 session
        sessionIsExpired = new Date() > expirationDate                      #Flag to determine whether or not the session has expired.
        if not session.data.recent_Articles  || sessionIsExpired            #remove sessions that did not see at least one article

          @.db.remove {sid: session.sid },{},(callback, deletedRecords)  =>
            if deletedRecords? == 0
              console.log("Unable to delete session with sid " + session.sid)
          cleared++
          if token?   #Safe check to invalidate TM 3.6 session.
            @.logout_User token,(response)=>
              #TM 3.6 backend response should be an empty guid.
              if not response? == '00000000-0000-0000-0000-000000000000'
                console.log("Error invalidating TM 3.6 session ")

      if cleared
        logger?.info "[Session_Service] removed #{cleared} sessions"
      callback()



  #TM Specific methods
  session_Data: (callback)=>
    @.db.find {}, (err,sessionData)=>
      callback sessionData

  viewed_Articles: (callback)=>
    @.db.find {}, (err,sessionData)=>
      viewed_Articles = @.DEFAULT_ARTICLES
      if sessionData
          for session in sessionData
              if session.data.recent_Articles
                  for recent_article in session.data.recent_Articles
                      viewed_Articles.add(recent_article)
      callback viewed_Articles

  users_Searches: (callback)=>
    @.db.find {}, (err,sessionData)=>
      users_Searches = @.DEFAULT_SEARCHES
      if sessionData
        for session in sessionData
          if session.data.user_Searches
            for user_Search in session.data.user_Searches
              if user_Search.results
                users_Searches.push(user_Search)
      callback users_Searches

  top_Articles: (callback)=>
    @.viewed_Articles (data)->
      if (is_Null(data))
          callback []
          return
      results = {}
      for item in data
          results[item.id] ?= { href: "/article/#{item.id}", title: item.title, weight: 0}
          results[item.id].weight++
      results = (results[key] for key in results.keys_Own())

      results = results.sort (a,b)-> a.weight - b.weight

      callback results.reverse()

  top_Searches: (callback)=>
    @.users_Searches (data)->
      if (is_Null(data))
          callback []
          return
      results = {}
      for item in data
        if item.title
          results[item.id] ?= { title: item.title, weight: 0}
          results[item.id].weight++
      results = (results[key] for key in results.keys_Own())

      results = results.sort (a,b)-> a.weight - b.weight

      callback results.reverse()

  user_Data: (session,callback)=>
    data = {}
    data.username        = session.username

    data.recent_Searches = []
    if session.user_Searches
      for user_Search in (session.user_Searches.reverse())
        if user_Search.results > 0 and data.recent_Searches.not_Contains(user_Search.title)
          data.recent_Searches.push user_Search.title
      data.recent_Searches = data.recent_Searches.slice(0,3)
      session.user_Searches.reverse()   # restore original order

    data.recent_Articles = []
    mapped_Articles = {}
    if session.recent_Articles
      for recent_Article in session.recent_Articles
        if not mapped_Articles[recent_Article.id]
          data.recent_Articles.push recent_Article
          mapped_Articles[recent_Article.id] = recent_Article
      data.recent_Articles = data.recent_Articles.slice(0,3)

    @.top_Searches (top_Searches)=>
      data.top_Searches = top_Searches.slice(0,3)

      @.top_Articles (top_Articles)=>
        data.top_Articles = top_Articles.slice(0, 3)
        callback data


#based on code from https://github.com/louischatriot/connect-nedb-session/blob/master/index.js

Session_Service.prototype.get =  (sid, callback)->
  this.db.findOne { sid: sid },  (err, sess)->
    if (err)
      return callback(err);
    if (!sess)
      return callback(null, null);

    return callback(null, sess.data);

Session_Service::set = (sid, data, callback)->
  this.db.update { sid: sid }, { sid: sid, data: data }, { multi: false, upsert: true },  (err)->
    return callback(err)

module.exports = Session_Service



