if process.cwd().contains('.dist')
  root_Folder = process.cwd().path_Combine '../../../'
else
  root_Folder = process.cwd().path_Combine '../../'

tm_Cache      = root_Folder.path_Combine '.tmCache'
tm_35_Server  = 'https://tmdev01-uno.teammentor.net/'
tmWebServices = 'Aspx_Pages/TM_WebServices.asmx'

global.config =
  tm_design :
    jade_Compilation_Enabled : true
    folder_Docs_Json         : root_Folder.path_Combine 'data/Lib_Docs-Json'
    folder_Jade_Files        : root_Folder.path_Combine 'code/TM_Jade'
    webServices              : tm_35_Server + tmWebServices

global.custom =
  express_Routes: (express)->
    log 'in express_Routes'

# preloading these dependencies since they take a while to load and are warping the timings of the Unit tests (like Article-Controller)
require 'teammentor' # 300 ms
require 'jade'       # 350 ms
require 'highlight'  # 25  ms
require 'cheerio'    # 5   ms
