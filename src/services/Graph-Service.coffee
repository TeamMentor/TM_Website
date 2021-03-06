class Graph_Service

  constructor: (options)->
    @.options    = options || {}
    @.dataFile   = './src/article-data.json'
    @.data       = null
    @.port       = global.config?.tm_graph?.port || 1332
    @.server     = @.options.server || "http://localhost:#{@.port}"
    #@.cache      = new Cache_Service('graph-service')

  article_Html: (article_Id, callback)=>
    if not article_Id
      callback ''
    else
      url_Article_Html = "#{@server}/data/article_Html/#{article_Id.url_Encode()}"
      url_Article_Html.GET_Json callback

  article: (article_Ref, callback)=>
    if not article_Ref
      callback ''
    else
      url_Article = "#{@server}/data/article/#{article_Ref.str().url_Encode()}"
      url_Article.GET_Json callback

  articles: (callback)=>
    url = "#{@server}/data/articles/"
    url.GET_Json callback

  server_Online: (callback)=>
    @.server.GET (html)->
      callback html isnt null

  graphDataFromGraphDB: (queryId, filters, callback)=>
    if not queryId or queryId.trim() is ''
      callback {}
    else
      if filters
        graphDataUrl = "#{@server}/data/query_tree_filtered/#{queryId.url_Encode()}/#{filters.url_Encode()}"
      else
        graphDataUrl = "#{@server}/data/query_tree/#{queryId.url_Encode()}"
      graphDataUrl.GET_Json callback

  library_Query: (callback)=>
    url = "#{@server}/data/library_Query"
    url.GET_Json callback

  resolve_To_Ids: (values, callback)=>
    if not values
      return callback {}
    url = "#{@server}/convert/to_ids/#{values.url_Encode()}"
    url.GET_Json callback

  root_Queries: (callback)=>
    url_root_queries = "#{@server}/data/root_queries"              # need to call this first to create the root_query mapping
    url_query_Tree = "#{@server}/data/query_tree/Root-Queries"
    url_root_queries.GET (root_queries)->
      url_query_Tree.GET_Json callback

  query_From_Text_Search: (text, callback)=>
    if not text
      callback null
      return

    url_Titles  = "#{@server}/search/query_titles"
    url_Convert = "#{@server}/convert/to_ids/#{text.url_Encode()}"
    url_Search  = "#{@server}/search/query_from_text_search/#{text.url_Encode()}"

    url_Titles.GET_Json (mappings)->                  # check if there is a direct match with a query
      text_Lower = text.lower()
      for mapping in mappings
        if mapping.title.lower() is text_Lower
          return callback mapping.id

      url_Convert.GET_Json (json)->                  # check if a query search found it
        mapping = json[json.keys?().first()]
        if mapping?.id?.contains 'query-'
          callback mapping.id
        else
          url_Search.GET (search_Id)->               # finally search by keyword
            callback search_Id

  node_Data: (id, callback)=>
    if not id
      callback ''
      return

    url_Node_Data = "#{@server}/data/id/#{id.str().url_Encode()}"
    
    url_Node_Data.GET_Json (json)->
      if json and json.values().not_Empty()
        callback json.values().first()
      else
        callback {}

  search_Log_Empty_Search : (user, value, callback)=>
    url_Log_Search = "#{@server}/user/log_search_empty/#{user?.url_Encode()}/#{value?.url_Encode()}"
    url_Log_Search.GET_Json (json)=>
      callback {}

module.exports = Graph_Service