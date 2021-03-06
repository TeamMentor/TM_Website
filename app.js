/*jslint node: true */
"use strict";
require('coffee-script/register');                      // enable coffee-script support
require('fluentnode');                                  // register fluentnode files
//require('./test/set-globals')                         // tmp until this is wired properly
//log(global.config.json_Pretty())

process.env.TM_SITE_DATA = "SiteData_TM";

var Side_Data = require('../TM_Shared/src/Site-Data');
var site_Data = new Side_Data()

//log('[SiteData] loading data from ' + site_Data.siteData_Folder())
global.config = site_Data.load_Options()
global.custom = site_Data.custom_Code()

console.log('------------global.config---------------')
console.log(global.config);
console.log('----------------------------------------')

var Express_Service    = require('./src/services/Express-Service');
var Analytics_Service  = require('./src/services/Analytics-Service');
var Hubspot_Service    = require('./src/services/Hubspot-Service');
var Anonymous_Service  = require('./src/services/Anonymous-Service');
new Express_Service()
      .setup()
      .start();
new Analytics_Service()
      .setup();
new Hubspot_Service()
      .setup();
new Anonymous_Service()
      .setup();

